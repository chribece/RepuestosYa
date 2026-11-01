'use strict';

function normalizeCity(value) {
  if (typeof value !== 'string') return '';
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .trim()
    .replace(/\s+/g, ' ')
    .toLowerCase();
}

function getRequestCity(request) {
  const relation = request?.direcciones_entrega;
  const address = Array.isArray(relation) ? relation[0] : relation;
  return address?.ciudad ?? request?.city ?? request?.ciudad;
}

function filterRequestsByCity(requests, city) {
  const normalizedCity = normalizeCity(city);
  if (!normalizedCity || !Array.isArray(requests)) return [];

  return requests.filter(
    (request) => normalizeCity(getRequestCity(request)) === normalizedCity,
  );
}

module.exports = { normalizeCity, getRequestCity, filterRequestsByCity };
