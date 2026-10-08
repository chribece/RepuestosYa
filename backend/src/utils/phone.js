/**
 * Normalización y validación de teléfonos (backend).
 *
 * Regla coherente con el frontend (Ecuador por defecto):
 * - Se almacena SOLO dígitos (sin +, espacios, guiones ni paréntesis), lo
 *   que satisface los CHECK `^[0-9]{9,}$` de `almacenes` y `profiles`.
 * - Válido si tiene entre 9 y 15 dígitos (local Ecuador 9-10, internacional
 *   E.164 hasta 15).
 * - Vacío/ausente → null (el campo es opcional en la API; la UI lo exige).
 */

const normalizarTelefono = (value) => {
  if (value === null || value === undefined) return null;
  const digits = String(value).replace(/\D/g, '');
  return digits === '' ? null : digits;
};

const telefonoValido = (value) => {
  const digits = normalizarTelefono(value);
  return digits !== null && digits.length >= 9 && digits.length <= 15;
};

module.exports = { normalizarTelefono, telefonoValido };
