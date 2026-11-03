/**
 * Utilidades de geolocalización para el flujo obligatorio de ubicación.
 *
 * Alcance: Ecuador. La ciudad indicada por el usuario participa en las
 * búsquedas manuales y Nominatim restringe los resultados por country code.
 *
 * - geocodeDireccion: geocodifica server-side la dirección textual del
 *   cliente vía Nominatim (OpenStreetMap) cuando el GPS del dispositivo está
 *   inoperable (hardware roto, permiso permanentemente denegado tras agotar
 *   el flujo de reintento/Ajustes). Es la única vía de degradación
 *   controlada: el registro NUNCA se guarda sin coordenadas de algún origen.
 *   Las búsquedas respetan el país configurado y la ciudad indicada.
 * - haversineKm / estimarTiempoDespachoMin: distancia real (km) y tiempo de
 *   despacho estimado (min) entre el almacén y el punto de entrega, usados
 *   por el backend al crear una cotización.
 *
 * Nota de uso de Nominatim: se envía un User-Agent identificando la app y se
 * respeta el límite de uso (1 petición/segundo); la política pública exige
 * identificarse correctamente (https://operations.osmfoundation.org/policies/nominatim/).
 */

const GEOCODING_TIMEOUT_MS = 8000;
const NOMINATIM_MIN_INTERVAL_MS = 1000;
const NOMINATIM_SEARCH_URL = 'https://nominatim.openstreetmap.org/search';
const NOMINATIM_USER_AGENT = 'RepuestosYaApp/1.0 (soporte@repuestosya.com)';
const RADIO_TIERRA_KM = 6371;
const VELOCIDAD_PROMEDIO_KMH = 30; // Traslado urbano conservador
const TIEMPO_PREPARACION_MIN = 20; // Alistamiento/embalaje antes del traslado
let nominatimQueue = Promise.resolve();
let ultimoInicioNominatim = 0;

const GEOCODING_NOT_FOUND_MESSAGE =
  'No pudimos ubicar esa dirección en Ecuador. Verifica la ciudad y la calle ingresadas.';

class GeocodingError extends Error {
  constructor(message, code = 'GEOCODING_FAILED') {
    super(message);
    this.name = 'GeocodingError';
    this.code = code;
  }
}

/**
 * Valida que un par de coordenadas sea numéricamente correcto.
 * @param {*} latitude
 * @param {*} longitude
 * @returns {boolean}
 */
function validarCoordenadas(latitude, longitude) {
  if (typeof latitude !== 'number' || typeof longitude !== 'number') {
    return false;
  }
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return false;
  }
  if (latitude < -90 || latitude > 90) return false;
  if (longitude < -180 || longitude > 180) return false;
  return true;
}

/**
 * Distancia en km entre dos coordenadas (fórmula de Haversine),
 * redondeada a 1 decimal.
 */
function haversineKm(lat1, lon1, lat2, lon2) {
  const aLat = (lat1 * Math.PI) / 180;
  const bLat = (lat2 * Math.PI) / 180;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;

  const h =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(aLat) * Math.cos(bLat) * Math.sin(dLon / 2) * Math.sin(dLon / 2);

  const distancia = RADIO_TIERRA_KM * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
  return Math.round(distancia * 10) / 10;
}

/**
 * Tiempo de despacho estimado en minutos: preparación + traslado a
 * velocidad promedio urbana.
 * @param {number} distanciaKm
 * @returns {number}
 */
function estimarTiempoDespachoMin(distanciaKm) {
  const trasladoMin = (distanciaKm / VELOCIDAD_PROMEDIO_KMH) * 60;
  return Math.round(TIEMPO_PREPARACION_MIN + trasladoMin);
}

/**
 * Construye el texto de búsqueda a partir de los campos de la dirección.
 * @param {{callePrincipal: string, ciudad?: string, calleSecundaria?: string, referencia?: string}} direccion
 * @returns {string}
 */
function formatearDireccionParaGeocoding({ callePrincipal, ciudad, calleSecundaria, referencia }) {
  const partes = [callePrincipal, calleSecundaria, referencia, ciudad].filter(
    (p) => typeof p === 'string' && p.trim().length > 0
  );
  const pais = process.env.GEOCODING_COUNTRY || 'Ecuador';
  return [...partes, pais].join(', ');
}

/**
 * Ejecuta una búsqueda simple contra Nominatim y devuelve los resultados.
 * La búsqueda se limita al país configurado (`countrycodes`, Ecuador por
 * defecto); no usa un viewbox urbano fijo para admitir otras ciudades.
 * Lanza GeocodingError si el servicio responde con error o tarda demasiado.
 */
async function buscarEnNominatim(query) {
  await esperarTurnoNominatim();
  const params = new URLSearchParams({
    q: query,
    format: 'json',
    limit: '1',
    addressdetails: '1',
    countrycodes: process.env.GEOCODING_COUNTRYCODES || 'ec',
    'accept-language': 'es'
  });

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), GEOCODING_TIMEOUT_MS);

  try {
    const response = await fetch(`${NOMINATIM_SEARCH_URL}?${params.toString()}`, {
      headers: {
        'User-Agent': NOMINATIM_USER_AGENT,
        'Accept': 'application/json'
      },
      signal: controller.signal
    });

    if (!response.ok) {
      throw new GeocodingError(
        `El servicio de geocodificación no está disponible (HTTP ${response.status}). Intenta nuevamente.`,
        'GEOCODING_UNAVAILABLE'
      );
    }

    const resultados = await response.json();
    return Array.isArray(resultados) ? resultados : [];
  } catch (error) {
    if (error instanceof GeocodingError) throw error;
    if (error.name === 'AbortError') {
      throw new GeocodingError(
        'La verificación de la ubicación tardó demasiado. Intenta nuevamente.',
        'GEOCODING_TIMEOUT'
      );
    }
    throw new GeocodingError(
      'No pudimos verificar la ubicación de la dirección. Intenta nuevamente.',
      'GEOCODING_FAILED'
    );
  } finally {
    clearTimeout(timer);
  }
}

async function esperarTurnoNominatim() {
  let liberarTurno;
  const turno = new Promise((resolve) => {
    liberarTurno = resolve;
  });
  const turnoAnterior = nominatimQueue;
  nominatimQueue = turno;
  await turnoAnterior;

  try {
    const espera = NOMINATIM_MIN_INTERVAL_MS -
      (Date.now() - ultimoInicioNominatim);
    if (espera > 0) {
      await new Promise((resolve) => setTimeout(resolve, espera));
    }
    ultimoInicioNominatim = Date.now();
  } finally {
    liberarTurno();
  }
}

/**
 * Geocodifica una dirección textual contra Nominatim (OpenStreetMap),
 * restringida al país configurado.
 *
 * Prueba primero la calle y ciudad, y luego agrega referencia u otras
 * variantes. Así una referencia escrita manualmente no impide guardar una
 * dirección que Nominatim sí reconoce por su vía principal y ciudad.
 *
 * @param {{callePrincipal: string, ciudad?: string, calleSecundaria?: string, referencia?: string}} direccion
 * @returns {Promise<{latitude: number, longitude: number, displayName: string}>}
 * @throws {GeocodingError} si la dirección no es resoluble en el país
 *   configurado, el servicio falla o tarda demasiado.
 */
async function geocodeDireccion(direccion) {
  const { callePrincipal, ciudad, calleSecundaria, referencia } = direccion;
  if (!callePrincipal || !callePrincipal.trim()) {
    throw new GeocodingError('La dirección está vacía y no se puede ubicar.');
  }

  const pais = process.env.GEOCODING_COUNTRY || 'Ecuador';
  const principal = callePrincipal.trim();
  const secundaria = typeof calleSecundaria === 'string'
    ? calleSecundaria.trim()
    : '';
  const referenciaLimpia = typeof referencia === 'string'
    ? referencia.trim()
    : '';
  const ciudadLimpia = typeof ciudad === 'string' ? ciudad.trim() : '';
  const queries = [];

  // Try the two streets as an intersection first, without reference text
  // that can overconstrain Nominatim. Then progressively simplify the query.
  if (secundaria) {
    queries.push(
      [
        `${principal} y ${secundaria}`,
        ciudadLimpia,
        pais
      ].filter(Boolean).join(', ')
    );
  }
  if (secundaria || referenciaLimpia) {
    queries.push(
      [principal, secundaria, referenciaLimpia, ciudadLimpia, pais]
        .filter(Boolean)
        .join(', ')
    );
  }
  queries.push([principal, ciudadLimpia, pais].filter(Boolean).join(', '));
  if (!ciudadLimpia) {
    queries.push([principal, pais].join(', '));
  }
  const queriesUnicas = [...new Set(queries)];

  for (const query of queriesUnicas) {
    const resultados = await buscarEnNominatim(query);
    if (resultados.length === 0) continue;

    const mejor = resultados[0];
    const latitude = parseFloat(mejor.lat);
    const longitude = parseFloat(mejor.lon);

    if (!validarCoordenadas(latitude, longitude)) {
      throw new GeocodingError(
        'La ubicación obtenida no es válida. Intenta con otra dirección o activa el GPS.',
        'GEOCODING_INVALID'
      );
    }

    const countryCode = mejor.address?.country_code?.toLowerCase();
    const allowedCountryCodes = (
      process.env.GEOCODING_COUNTRYCODES || 'ec'
    ).split(',').map((code) => code.trim().toLowerCase());
    if (countryCode && !allowedCountryCodes.includes(countryCode)) {
      continue;
    }

    return {
      latitude,
      longitude,
      displayName: mejor.display_name || null
    };
  }

  throw new GeocodingError(GEOCODING_NOT_FOUND_MESSAGE, 'GEOCODING_NOT_FOUND');
}

module.exports = {
  GeocodingError,
  validarCoordenadas,
  GEOCODING_NOT_FOUND_MESSAGE,
  haversineKm,
  estimarTiempoDespachoMin,
  formatearDireccionParaGeocoding,
  geocodeDireccion
};
