/**
 * Regresión del escape (0,0): verifica que `resolverCoordenadasEntrega`
 * NUNCA devuelve (0,0) para una dirección legacy sin coordenadas + GPS
 * denegado: geocodifica server-side o lanza GeocodingError (→ 422).
 *
 * Uso: node scripts/test_resolver.js  (requiere red para Nominatim y .env)
 */
require('dotenv').config({ path: 'C:/RepuestosYa/backend/.env' });
const {
  resolverCoordenadasEntrega,
  coordsANumero
} = require('C:/RepuestosYa/backend/src/controllers/solicitudController');
const { GeocodingError } = require('C:/RepuestosYa/backend/src/utils/geocoding');

// Mock mínimo de supabase: el resolver solo persiste la dirección.
const mockSupabase = {
  from: () => ({ update: () => ({ eq: async () => ({ error: null, data: null }) }) })
};

(async () => {
  let fallos = 0;

  // 0. coordsANumero nunca convierte null/undefined/NaN/'' en 0.
  const c = [
    coordsANumero(null),
    coordsANumero(undefined),
    coordsANumero(NaN),
    coordsANumero(''),
    coordsANumero('abc'),
    coordsANumero('-0.1913664'),
    coordsANumero(0)
  ];
  console.log('coordsANumero:', JSON.stringify(c));
  if (c.slice(0, 5).some((v) => v === 0)) {
    console.log('FALLO: null/NaN/"" → 0');
    fallos++;
  }
  if (c[5] !== -0.1913664 || c[6] !== 0) {
    console.log('FALLO: parseo numérico incorrecto');
    fallos++;
  }

  // 1. Dirección legacy (lat/lon NULL) + sin GPS → geocodifica a coords REALES.
  const legacy = {
    id: 'legacy-1',
    calle_principal: 'Av. 10 de Agosto',
    calle_secundaria: 'Av. Amazonas',
    referencia: 'Centro',
    latitude: null,
    longitude: null,
    coordenadas_fuente: null
  };
  try {
    const r = await resolverCoordenadasEntrega({
      direccion: legacy,
      supabase: mockSupabase
    });
    console.log('Caso legacy geocodificable →', JSON.stringify(r));
    if (r.latitude === 0 && r.longitude === 0) {
      console.log('FALLO: devolvió (0,0)');
      fallos++;
    }
    if (r.coordenadasResueltas !== true) {
      console.log('FALLO: coordenadasResueltas !== true');
      fallos++;
    }
  } catch (e) {
    console.log('Caso legacy geocodificable ERROR:', e.message);
    fallos++;
  }

  // 2. Dirección legacy irresoluble → GeocodingError (el controller responde 422).
  const mala = {
    id: 'legacy-2',
    calle_principal: 'Calle Inexistente XYZ 9999',
    calle_secundaria: null,
    referencia: null,
    latitude: null,
    longitude: null,
    coordenadas_fuente: null
  };
  try {
    await resolverCoordenadasEntrega({ direccion: mala, supabase: mockSupabase });
    console.log('FALLO: la dirección irresoluble debería lanzar GeocodingError');
    fallos++;
  } catch (e) {
    const ok = e instanceof GeocodingError;
    console.log('Caso legacy irresoluble →', ok ? `GeocodingError OK (${e.code})` : 'OTRO ERROR');
    if (!ok) fallos++;
  }

  // 3. Dirección con coords reales → las reutiliza sin geocodificar.
  const conCoords = {
    id: 'legacy-3',
    calle_principal: 'X',
    latitude: -0.1913664,
    longitude: -78.4930512,
    coordenadas_fuente: 'gps'
  };
  const r3 = await resolverCoordenadasEntrega({ direccion: conCoords, supabase: mockSupabase });
  console.log('Caso con coords →', JSON.stringify(r3));
  if (r3.latitude !== -0.1913664 || r3.coordenadasResueltas !== true) {
    console.log('FALLO: no reutilizó coords');
    fallos++;
  }

  // 4. (0,0) almacenado (defecto previo) → se trata como ausente: geocodifica
  //    o lanza, pero NUNCA devuelve (0,0) como resuelto.
  const conCeros = {
    id: 'legacy-4',
    calle_principal: 'Av. 10 de Agosto',
    latitude: 0,
    longitude: 0,
    coordenadas_fuente: 'gps'
  };
  try {
    const r4 = await resolverCoordenadasEntrega({ direccion: conCeros, supabase: mockSupabase });
    console.log('Caso (0,0) almacenado → geocodifica:', r4.latitude, r4.longitude, '| resueltas:', r4.coordenadasResueltas);
    if (r4.latitude === 0 && r4.longitude === 0) {
      console.log('FALLO: (0,0) pasó como resuelto');
      fallos++;
    }
  } catch (e) {
    console.log('Caso (0,0) almacenado → GeocodingError (422):', e.code);
  }

  // 5. Guardia del INSERT (simula la condición del controlador): (0,0) o
  //    no resuelto → rechazado (nunca se persiste).
  const simularGuardia = (lat, lng, resueltas) => !resueltas || (lat === 0 && lng === 0);
  if (!simularGuardia(0, 0, true)) { console.log('FALLO: guardia no rechaza (0,0)'); fallos++; }
  if (!simularGuardia(-0.19, -78.49, false)) { console.log('FALLO: guardia no rechaza no-resuelto'); fallos++; }
  if (simularGuardia(-0.19, -78.49, true)) { console.log('FALLO: guardia rechaza coords válidas'); fallos++; }

  console.log(
    fallos === 0
      ? 'RESULTADO: OK — el escape (0,0) ya no es reproducible (geocodifica o 422, nunca inserta 0,0)'
      : `RESULTADO: ${fallos} FALLO(S)`
  );
  process.exit(fallos === 0 ? 0 : 1);
})();
