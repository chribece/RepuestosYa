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
  'No encontramos la calle principal en esa ciudad. Verifica el nombre de la calle y la ciudad.';

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
  const campos = normalizarCamposDireccion({
    callePrincipal,
    ciudad,
    calleSecundaria,
    referencia
  });
  const partes = [
    campos.callePrincipal,
    campos.calleSecundaria,
    campos.referencia,
    campos.ciudad
  ].filter(Boolean);
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
    limit: '5',
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

function normalizarTextoUbicacion(value) {
  return typeof value === 'string'
    ? value
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, ' ')
        .trim()
        .replace(/\s+/g, ' ')
    : '';
}

function limpiarTextoDireccion(value) {
  return typeof value === 'string' ? value.trim().replace(/\s+/g, ' ') : '';
}

function claveTextoDireccion(value) {
  return normalizarTextoUbicacion(limpiarTextoDireccion(value))
    .replace(/^(sector|barrio|urbanizacion|lotizacion|conjunto|ciudadela)\s+/, '')
    .replace(/\b(avenida|av|calle|cl|callejon|via|carretera)\b/g, ' ')
    .replace(/[^a-z0-9]/g, '');
}

function normalizarCamposDireccion(direccion = {}) {
  const principal = limpiarTextoDireccion(direccion.callePrincipal);
  let secundaria = limpiarTextoDireccion(direccion.calleSecundaria);
  let referencia = limpiarTextoDireccion(direccion.referencia);
  const principalKey = claveTextoDireccion(principal);

  if (principalKey && principalKey === claveTextoDireccion(secundaria)) {
    secundaria = '';
  }
  const referenciaKey = claveTextoDireccion(referencia);
  if (
    referenciaKey &&
    (referenciaKey === principalKey ||
      referenciaKey === claveTextoDireccion(secundaria) ||
      referenciaKey === claveTextoDireccion(direccion.calleSecundaria))
  ) {
    referencia = '';
  }

  return {
    ciudad: limpiarTextoDireccion(direccion.ciudad),
    callePrincipal: principal,
    calleSecundaria: secundaria,
    referencia
  };
}

function normalizarNombreVia(value) {
  return normalizarTextoUbicacion(value)
    .replace(/\b(avenida|av|calle|cl|callejon|via|carretera)\b/g, ' ')
    .trim()
    .replace(/\s+/g, ' ');
}

function coincideNombreUbicacion(candidatos, solicitado) {
  const objetivo = normalizarNombreVia(solicitado);
  if (!objetivo) return true;
  return candidatos.some((candidato) => {
    const nombre = normalizarNombreVia(candidato);
    return nombre && (nombre === objetivo || nombre.includes(objetivo));
  });
}

function coincideCiudad(resultado, ciudad) {
  const objetivo = normalizarTextoUbicacion(ciudad);
  if (!objetivo) return true;

  const address = resultado.address || {};
  const candidatos = [
    address.city,
    address.town,
    address.village,
    address.municipality,
    address.city_district,
    address.county,
    ...(typeof resultado.display_name === 'string'
      ? resultado.display_name.split(',')
      : [])
  ].filter((value) => typeof value === 'string' && value.trim());

  return candidatos.some((candidato) => {
    const nombre = normalizarTextoUbicacion(candidato);
    return nombre === objetivo;
  });
}

function coincideConCalles(resultado, callePrincipal, calleSecundaria) {
  const address = resultado.address || {};
  const roadFields = [
    address.road,
    address.pedestrian,
    address.residential,
    address.highway,
    address.street,
    address.unclassified,
    address.tertiary,
    address.secondary,
    address.primary,
    address.service,
    address.footway,
    address.path
  ].filter((value) => typeof value === 'string' && value.trim());

  if (!coincideNombreUbicacion([...roadFields, resultado.display_name], callePrincipal)) {
    return false;
  }

  const secundariaReportada = [
    address.secondary_road,
    address.crossing,
    address.cross_street,
    address.cross_street_name,
    address.street_2,
    address.road_2,
    address.intersection,
    ...roadFields.filter((via) =>
      normalizarNombreVia(via) !== normalizarNombreVia(callePrincipal)
    )
  ].filter((value) => typeof value === 'string' && value.trim());
  return secundariaReportada.length === 0
    ? true
    : coincideNombreUbicacion(secundariaReportada, calleSecundaria);
}

function coincideCalleSecundariaReportada(resultado, calleSecundaria) {
  if (!calleSecundaria) return false;
  const address = resultado.address || {};
  const vias = [
    address.secondary_road,
    address.crossing,
    address.cross_street,
    address.cross_street_name,
    address.street_2,
    address.road_2,
    address.intersection,
    address.road,
    address.pedestrian,
    address.residential,
    address.highway,
    address.street,
    address.unclassified,
    address.tertiary,
    address.secondary,
    address.primary,
    address.service,
    resultado.display_name
  ].filter((value) => typeof value === 'string' && value.trim());

  const solicitada = normalizarNombreVia(calleSecundaria);
  if (!solicitada) return false;
  return vias.some((via) => {
    const partes = via
      .split(/[,;]/)
      .flatMap((parte) => parte.split(/\s+(?:y|and|con|&)\s+|\s*\/\s*/i));
    return partes.some((parte) => normalizarNombreVia(parte) === solicitada);
  });
}

/**
 * Geocodifica una dirección textual contra Nominatim (OpenStreetMap),
 * restringida al país configurado.
 *
 * Si se indican ambas vías, solo devuelve resultados que reportan ambas
 * dentro de la ciudad. Sin calle secundaria, admite un punto aproximado en la
 * calle principal.
 *
 * @param {{callePrincipal: string, ciudad?: string, calleSecundaria?: string, referencia?: string}} direccion
 * @returns {Promise<{latitude: number, longitude: number, displayName: string, ubicacionAproximada: boolean}>}
 * @throws {GeocodingError} si la dirección no es resoluble en el país
 *   configurado, el servicio falla o tarda demasiado.
 */
async function geocodeDireccion(direccion) {
  const campos = normalizarCamposDireccion(direccion);
  const {
    callePrincipal,
    ciudad: ciudadLimpia,
    calleSecundaria: secundaria,
    referencia: referenciaLimpia
  } = campos;
  if (!callePrincipal) {
    throw new GeocodingError('La dirección está vacía y no se puede ubicar.');
  }

  const pais = process.env.GEOCODING_COUNTRY || 'Ecuador';
  const principal = callePrincipal;
  if (secundaria && !ciudadLimpia) {
    throw new GeocodingError(
      'Indica la ciudad para validar la intersección de las dos calles.',
      'GEOCODING_CITY_REQUIRED'
    );
  }
  const queries = [];

  // Ask for the crossing first; references can distract free-form geocoders
  // from the intersection point.
  if (secundaria) {
    queries.push(
      [
        `${principal} & ${secundaria}`,
        ciudadLimpia,
        pais
      ].filter(Boolean).join(', ')
    );
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
  if (!secundaria) {
    queries.push([principal, ciudadLimpia, pais].filter(Boolean).join(', '));
    if (!ciudadLimpia) {
      queries.push([principal, pais].join(', '));
    }
  }
  const queriesUnicas = [...new Set(queries)];

  for (const query of queriesUnicas) {
    const resultados = await buscarEnNominatim(query);
    if (resultados.length === 0) continue;

    const allowedCountryCodes = (
      process.env.GEOCODING_COUNTRYCODES || 'ec'
    ).split(',').map((code) => code.trim().toLowerCase());
    for (const resultado of resultados) {
      const latitude = parseFloat(resultado.lat);
      const longitude = parseFloat(resultado.lon);
      if (!validarCoordenadas(latitude, longitude)) continue;

      const countryCode = resultado.address?.country_code?.toLowerCase();
      if (countryCode && !allowedCountryCodes.includes(countryCode)) continue;
      if (!coincideCiudad(resultado, ciudadLimpia)) continue;
      if (!coincideConCalles(resultado, principal, secundaria)) continue;

      const coincideViaPrincipal = coincideCalleSecundariaReportada(
        resultado,
        principal
      );
      const coincideViaSecundaria = coincideCalleSecundariaReportada(
        resultado,
        secundaria
      );
      if (secundaria && (!coincideViaPrincipal || !coincideViaSecundaria)) {
        continue;
      }

      const ubicacion = {
        latitude,
        longitude,
        displayName: resultado.display_name || null,
        ubicacionAproximada: !secundaria
      };
      return ubicacion;
    }
  }

  if (secundaria) {
    throw new GeocodingError(
      'No encontramos el cruce exacto de las dos calles dentro de esa ciudad. Verifica los nombres de ambas vías.',
      'GEOCODING_NOT_FOUND'
    );
  }
  throw new GeocodingError(GEOCODING_NOT_FOUND_MESSAGE, 'GEOCODING_NOT_FOUND');
}

module.exports = {
  GeocodingError,
  validarCoordenadas,
  GEOCODING_NOT_FOUND_MESSAGE,
  limpiarTextoDireccion,
  normalizarCamposDireccion,
  haversineKm,
  estimarTiempoDespachoMin,
  formatearDireccionParaGeocoding,
  geocodeDireccion
};
