'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const {
  GeocodingError,
  geocodeDireccion
} = require('../src/utils/geocoding');

test('geocodifica dirección manual con calle secundaria, referencia y ciudad', async () => {
  const originalFetch = global.fetch;
  const queries = [];
  global.fetch = async (url) => {
    const query = new URL(url).searchParams.get('q');
    queries.push(query);
    return {
      ok: true,
      json: async () => queries.length < 3
        ? []
        : [{
          lat: '-0.20',
          lon: '-78.50',
          display_name: 'Calle Venezuela y Buenos Aires, Quito, Ecuador',
          address: {
            country_code: 'ec',
            road: 'Venezuela',
            secondary_road: 'Buenos Aires',
            city: 'Quito'
          }
        }]
    };
  };

  try {
    const result = await geocodeDireccion({
      callePrincipal: 'Venezuela',
      calleSecundaria: 'Buenos Aires',
      referencia: 'diagonal al mercado América',
      ciudad: 'Quito'
    });

    assert.deepEqual(result, {
      latitude: -0.2,
      longitude: -78.5,
      displayName: 'Calle Venezuela y Buenos Aires, Quito, Ecuador'
    });
    assert.equal(queries.length, 3);
    assert.equal(queries[0], 'Venezuela y Buenos Aires, Quito, Ecuador');
    assert.equal(queries[2], 'Venezuela, Quito, Ecuador');
  } finally {
    global.fetch = originalFetch;
  }
});

test('acepta la coincidencia de calle y ciudad cuando Nominatim omite la transversal', async () => {
  const originalFetch = global.fetch;
  global.fetch = async () => ({
    ok: true,
    json: async () => [{
      lat: '-0.20',
      lon: '-78.50',
      display_name: 'Calle Venezuela, Quito, Ecuador',
      address: {
        country_code: 'ec',
        road: 'Venezuela',
        city: 'Quito'
      }
    }]
  });

  try {
    const result = await geocodeDireccion({
      callePrincipal: 'Venezuela',
      calleSecundaria: 'Buenos Aires',
      referencia: 'diagonal al mercado América',
      ciudad: 'Quito'
    });

    assert.equal(result.latitude, -0.2);
    assert.equal(result.longitude, -78.5);
  } finally {
    global.fetch = originalFetch;
  }
});

test('acepta ciudades ecuatorianas distintas de Quito', async () => {
  const originalFetch = global.fetch;
  global.fetch = async () => ({
    ok: true,
    json: async () => [{
      lat: '-2.17',
      lon: '-79.92',
      display_name: 'Av. Principal, Guayaquil, Ecuador',
      address: { country_code: 'ec' }
    }]
  });

  try {
    const result = await geocodeDireccion({
      callePrincipal: 'Av. Principal',
      ciudad: 'Guayaquil'
    });
    assert.equal(result.latitude, -2.17);
    assert.equal(result.longitude, -79.92);
  } finally {
    global.fetch = originalFetch;
  }
});

test('rechaza resultados fuera del país permitido', async () => {
  const originalFetch = global.fetch;
  global.fetch = async () => ({
    ok: true,
    json: async () => [{
      lat: '-12.05',
      lon: '-77.04',
      display_name: 'Calle, Lima, Perú',
      address: { country_code: 'pe' }
    }]
  });

  try {
    await assert.rejects(
      geocodeDireccion({
        callePrincipal: 'Calle',
        ciudad: 'Quito'
      }),
      (error) => error instanceof GeocodingError &&
        error.code === 'GEOCODING_NOT_FOUND'
    );
  } finally {
    global.fetch = originalFetch;
  }
});

test('no acepta un punto genérico de ciudad sin coincidencia de calle', async () => {
  const originalFetch = global.fetch;
  global.fetch = async () => ({
    ok: true,
    json: async () => [{
      lat: '-0.20',
      lon: '-78.50',
      display_name: 'Quito, Ecuador',
      address: { country_code: 'ec', city: 'Quito' }
    }]
  });

  try {
    await assert.rejects(
      geocodeDireccion({
        callePrincipal: 'Venezuela',
        calleSecundaria: 'Buenos Aires',
        ciudad: 'Quito'
      }),
      (error) => error instanceof GeocodingError &&
        error.code === 'GEOCODING_NOT_FOUND'
    );
  } finally {
    global.fetch = originalFetch;
  }
});
