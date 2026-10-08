/**
 * Tests del util de teléfono del backend (src/utils/phone.js):
 * normalización a dígitos y validación 9-15 (Ecuador 9-10, E.164 hasta 15).
 *
 * Uso: node --test tests/phone.test.js
 */
const { test } = require('node:test');
const assert = require('node:assert/strict');

const {
  normalizarTelefono,
  telefonoValido,
} = require('../src/utils/phone');

test('normaliza "+593 998757857" (formato real Ecuador) → dígitos', () => {
  assert.equal(normalizarTelefono('+593 998757857'), '593998757857');
  assert.equal(normalizarTelefono('+593998757857'), '593998757857');
});

test('normaliza "0998757857" (celular local) → dígitos', () => {
  assert.equal(normalizarTelefono('0998757857'), '0998757857');
});

test('normaliza espacios, guiones y paréntesis', () => {
  assert.equal(normalizarTelefono('(099) 123-4567'), '0991234567');
});

test('normaliza números internacionales con +', () => {
  assert.equal(normalizarTelefono('+1 555 123 4567'), '15551234567');
});

test('vacío / ausente / sin dígitos → null', () => {
  assert.equal(normalizarTelefono(null), null);
  assert.equal(normalizarTelefono(undefined), null);
  assert.equal(normalizarTelefono(''), null);
  assert.equal(normalizarTelefono('   '), null);
  assert.equal(normalizarTelefono('abc-()'), null);
});

test('telefonoValido: 9-15 dígitos (Ecuador e internacional)', () => {
  assert.equal(telefonoValido('+593 998757857'), true); // 12 dígitos
  assert.equal(telefonoValido('0991234567'), true); // 10 dígitos
  assert.equal(telefonoValido('998757857'), true); // 9 dígitos
  assert.equal(telefonoValido('+1 555 123 4567'), true); // 11 dígitos
  assert.equal(telefonoValido('59399123456789123'), false); // 17 dígitos
  assert.equal(telefonoValido('12345678'), false); // 8 dígitos
  assert.equal(telefonoValido(null), false);
  assert.equal(telefonoValido(''), false);
});
