/**
 * Utilidades de geolocalización para el flujo obligatorio de ubicación.
 *
 * ALCANCE ACTUAL: SOLO QUITO. Cuando se expanda a otras ciudades, agregar
 * campo `ciudad` al formulario de direcciones y parametrizar el viewbox por
 * ciudad.
 *
 * - geocodeDireccion: geocodifica server-side la dirección textual del
 *   cliente vía Nominatim (OpenStreetMap) cuando el GPS del dispositivo está
 *   inoperable (hardware roto, permiso permanentemente denegado tras agotar
 *   el flujo de reintento/Ajustes). Es la única vía de degradación
 *   controlada: el registro NUNCA se guarda sin coordenadas de algún origen.
 *   Las búsquedas se limitan al viewbox del Distrito Metropolitano de Quito
 *   (`bounded=1`) y, como doble check, las coordenadas devueltas se validan
 *   dentro de esa caja antes de aceptarlas; fuera de Quito se rechaza como
 *   "no encontrado" (422 con field 'ubicacion').
 * - haversineKm / estimarTiempoDespachoMin: distancia real (km) y tiempo de
 *   despacho estimado (min) entre el almacén y el punto de entrega, usados
 *   por el backend al crear una cotización.
 *
 * Nota de uso de Nominatim: se envía un User-Agent identificando la app y se
 * respeta el límite de uso (1 petición/segundo); la política pública exige
 * identificarse correctamente (https://operations.osmfoundation.org/policies/nominatim/).
 */

const GEOCODING_TIMEOUT_MS = 8000;
const NOMINATIM_SEARCH_URL = 'https://nominatim.openstreetmap.org/search';
const NOMINATIM_USER_AGENT = 'RepuestosYaApp/1.0 (soporte@repuestosya.com)';
const RADIO_TIERRA_KM = 6371;
const VELOCIDAD_PROMEDIO_KMH = 30; // Traslado urbano conservador
const TIEMPO_PREPARACION_MIN = 20; // Alistamiento/embalaje antes del traslado

// Viewbox del Distrito Metropolitano de Quito (límites oficiales de OSM,
// relación 113714, verificado contra el boundingbox y el polígono de
// Nominatim el 2026-09-19). Formato Nominatim: viewbox=left,top,right,bottom.
const QUITO_VIEWBOX = {
  minLat: -0.5956779,
  maxLat: 0.2562735,
  minLon: -78.9476819,
  maxLon: -78.1649035
};

// Mensaje único para direcciones que no se pueden ubicar DENTRO de Quito
// (no encontradas o fuera del viewbox). Se mapea a 422 con field 'ubicacion'.
const GEOCODING_FUERA_DE_QUITO_MESSAGE =
  'No pudimos ubicar esa dirección dentro de Quito. Verifica el texto ingresado.';

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
 * Verifica que un par de coordenadas caiga dentro del viewbox del
 * Distrito Metropolitano de Quito (doble check sobre la respuesta de
 * Nominatim: no se confía solo en el parámetro bounded=1).
 * @param {number} latitude
 * @param {number} longitude
 * @returns {boolean}
 */
function dentroDeViewboxQuito(latitude, longitude) {
  if (!validarCoordenadas(latitude, longitude)) return false;
  return (
    latitude >= QUITO_VIEWBOX.minLat &&
    latitude <= QUITO_VIEWBOX.maxLat &&
    longitude >= QUITO_VIEWBOX.minLon &&
    longitude <= QUITO_VIEWBOX.maxLon
  );
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
 * @param {{callePrincipal: string, calleSecundaria?: string, referencia?: string}} direccion
 * @returns {string}
 */
function formatearDireccionParaGeocoding({ callePrincipal, calleSecundaria, referencia }) {
  const partes = [callePrincipal, calleSecundaria, referencia].filter(
    (p) => typeof p === 'string' && p.trim().length > 0
  );
  const pais = process.env.GEOCODING_COUNTRY || 'Ecuador';
  return [...partes, pais].join(', ');
}

/**
 * Ejecuta una búsqueda simple contra Nominatim y devuelve los resultados.
 * La búsqueda está acotada al viewbox del Distrito Metropolitano de Quito
 * (bounded=1): solo se consideran resultados dentro de esa caja.
 * Lanza GeocodingError si el servicio responde con error o tarda demasiado.
 */
async function buscarEnNominatim(query) {
  // Formato Nominatim: viewbox=left,top,right,bottom (lon_min,lat_max,lon_max,lat_min)
  const viewbox = [
    QUITO_VIEWBOX.minLon,
    QUITO_VIEWBOX.maxLat,
    QUITO_VIEWBOX.maxLon,
    QUITO_VIEWBOX.minLat
  ].join(',');

  const params = new URLSearchParams({
    q: query,
    format: 'json',
    limit: '1',
    countrycodes: process.env.GEOCODING_COUNTRYCODES || 'ec',
    'accept-language': 'es',
    viewbox,
    bounded: '1'
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

/**
 * Geocodifica una dirección textual contra Nominatim (OpenStreetMap),
 * restringida al Distrito Metropolitano de Quito.
 *
 * Estrategia de búsqueda (las direcciones del cliente no incluyen ciudad):
 * 1. Texto completo (calles + referencia + país), para capturar la precisión
 *    de la referencia cuando el buscador la entiende.
 * 2. Fallback a la calle principal + país, que es el formato más confiable
 *    (las intersecciones tipo "Calle A y Calle B" no son resolubles).
 * Ambos intentos usan el mismo viewbox de Quito (bounded=1) y el resultado
 * se valida en código dentro de la caja; fuera de ella se rechaza como
 * "no encontrado" (mismo mensaje de error).
 *
 * @param {{callePrincipal: string, calleSecundaria?: string, referencia?: string}} direccion
 * @returns {Promise<{latitude: number, longitude: number, displayName: string}>}
 * @throws {GeocodingError} si la dirección no es resoluble (incluye fuera de
 *   Quito), el servicio falla o tarda demasiado.
 */
async function geocodeDireccion(direccion) {
  const { callePrincipal, calleSecundaria, referencia } = direccion;
  if (!callePrincipal || !callePrincipal.trim()) {
    throw new GeocodingError('La dirección está vacía y no se puede ubicar.');
  }

  const pais = process.env.GEOCODING_COUNTRY || 'Ecuador';
  const partesCompletas = [callePrincipal.trim(), calleSecundaria && calleSecundaria.trim(), referencia && referencia.trim()]
    .filter((p) => typeof p === 'string' && p.length > 0);

  const queries = [];
  if (partesCompletas.length > 1) {
    queries.push([...partesCompletas, pais].join(', '));
  }
  queries.push(`${callePrincipal.trim()}, ${pais}`);

  for (const query of queries) {
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

    // Doble check: aunque la petición usó bounded=1, se valida en código que
    // el resultado caiga dentro del viewbox de Quito. Fuera → "no encontrado".
    if (!dentroDeViewboxQuito(latitude, longitude)) {
      throw new GeocodingError(GEOCODING_FUERA_DE_QUITO_MESSAGE, 'GEOCODING_NOT_FOUND');
    }

    return {
      latitude,
      longitude,
      displayName: mejor.display_name || null
    };
  }

  // Sin resultados dentro de Quito (o dirección inexistente): mismo mensaje
  // de rechazo, mapeado a 422 con field 'ubicacion' por los controladores.
  throw new GeocodingError(GEOCODING_FUERA_DE_QUITO_MESSAGE, 'GEOCODING_NOT_FOUND');
}

module.exports = {
  GeocodingError,
  validarCoordenadas,
  dentroDeViewboxQuito,
  QUITO_VIEWBOX,
  GEOCODING_FUERA_DE_QUITO_MESSAGE,
  haversineKm,
  estimarTiempoDespachoMin,
  formatearDireccionParaGeocoding,
  geocodeDireccion
};
