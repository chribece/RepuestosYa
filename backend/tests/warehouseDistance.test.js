'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const {
  addDistanceToRequests,
  distanceBetweenWarehouseAndRequest,
  requestCoordinates
} = require('../src/utils/warehouseDistance');

test('calcula la distancia de la sucursal al snapshot de entrega', () => {
  const warehouse = { latitude: -0.18, longitude: -78.49 };
  const request = {
    latitud_entrega: '-0.19',
    longitud_entrega: '-78.49',
    direcciones_entrega: { latitude: -0.2, longitude: -78.5 }
  };

  assert.equal(distanceBetweenWarehouseAndRequest(warehouse, request), 1.1);
});

test('usa el par de coordenadas de la dirección si el snapshot está incompleto', () => {
  assert.deepEqual(
    requestCoordinates({
      latitud_entrega: -0.19,
      longitud_entrega: null,
      direcciones_entrega: [{ latitude: -0.19, longitude: -78.49 }]
    }),
    { latitude: -0.19, longitude: -78.49 }
  );
});

test('no calcula distancia con coordenadas ausentes, inválidas o (0,0)', () => {
  assert.equal(
    distanceBetweenWarehouseAndRequest(
      { latitude: 0, longitude: 0 },
      { latitud_entrega: -0.19, longitud_entrega: -78.49 }
    ),
    null
  );
  assert.equal(
    distanceBetweenWarehouseAndRequest(
      { latitude: -0.18, longitude: -78.49 },
      { latitud_entrega: null, longitud_entrega: null }
    ),
    null
  );
  assert.equal(
    distanceBetweenWarehouseAndRequest(
      { latitude: 91, longitude: -78.49 },
      { latitud_entrega: -0.19, longitud_entrega: -78.49 }
    ),
    null
  );
});

test('anota distancia nula sin reemplazarla por un valor de prueba', () => {
  const result = addDistanceToRequests(
    [{ id: 'missing-location', latitud_entrega: null, longitud_entrega: null }],
    { latitude: -0.18, longitude: -78.49 }
  );

  assert.equal(result[0].distancia_km, null);
});
