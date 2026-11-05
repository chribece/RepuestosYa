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

/**
 * Teléfono móvil ecuatoriano en el formato almacenado (9 dígitos desde el 9),
 * aceptando +593/593 y 09 como prefijo. Devuelve null si no es válido.
 */
const telefonoEcuadorCanonico = (value) => {
  let digits = normalizarTelefono(value);
  if (digits && digits.length === 12 && digits.startsWith('593')) digits = digits.slice(3);
  else if (digits && digits.length === 10 && digits.startsWith('09')) digits = digits.slice(1);
  return digits && /^9\d{8}$/.test(digits) ? digits : null;
};

module.exports = { normalizarTelefono, telefonoValido, telefonoEcuadorCanonico };
