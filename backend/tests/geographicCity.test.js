'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const {
  normalizeCity,
  filterRequestsByCity
} = require('../src/utils/geographicCity');

test('normaliza espacios, mayúsculas y tildes de ciudades', () => {
  assert.equal(normalizeCity('  SANTO   DOMINGO '), 'santo domingo');
  assert.equal(normalizeCity('Durán'), 'duran');
});

test('filtra solicitudes por coincidencia exacta con la ciudad de cobertura', () => {
  const requests = [
    { id: 'same-city', direcciones_entrega: { ciudad: 'Quito' } },
    { id: 'normalized-city', direcciones_entrega: [{ ciudad: '  QUÍTO ' }] },
    { id: 'other-city', direcciones_entrega: { ciudad: 'Cuenca' } },
    { id: 'missing-city', direcciones_entrega: null }
  ];

  assert.deepEqual(
    filterRequestsByCity(requests, 'Quito').map((request) => request.id),
    ['same-city', 'normalized-city']
  );
});

test('no filtra solicitudes si el establecimiento no tiene ciudad', () => {
  assert.deepEqual(
    filterRequestsByCity([{ id: 'unknown', city: 'Quito' }], ''),
    []
  );
});
