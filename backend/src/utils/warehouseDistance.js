'use strict';

const { haversineKm, validarCoordenadas } = require('./geocoding');

function parseCoordinate(value) {
  if (value === null || value === undefined) return null;
  if (typeof value === 'string' && value.trim() === '') return null;
  const coordinate =
    typeof value === 'number' ? value : Number(value.toString().trim());
  return Number.isFinite(coordinate) ? coordinate : null;
}

function validCoordinatePair(latitude, longitude) {
  return (
    validarCoordenadas(latitude, longitude) &&
    !(latitude === 0 && longitude === 0)
  );
}

function warehouseCoordinates(warehouse) {
  const latitude = parseCoordinate(warehouse?.latitude);
  const longitude = parseCoordinate(warehouse?.longitude);
  return validCoordinatePair(latitude, longitude)
    ? { latitude, longitude }
    : null;
}

function deliveryAddress(request) {
  const relation = request?.direcciones_entrega;
  if (Array.isArray(relation)) {
    const first = relation[0];
    return first && typeof first === 'object' ? first : null;
  }
  return relation && typeof relation === 'object' ? relation : null;
}

function requestCoordinates(request) {
  const snapshotLatitude = parseCoordinate(request?.latitud_entrega);
  const snapshotLongitude = parseCoordinate(request?.longitud_entrega);
  if (validCoordinatePair(snapshotLatitude, snapshotLongitude)) {
    return { latitude: snapshotLatitude, longitude: snapshotLongitude };
  }

  const address = deliveryAddress(request);
  const addressLatitude = parseCoordinate(address?.latitude);
  const addressLongitude = parseCoordinate(address?.longitude);
  return validCoordinatePair(addressLatitude, addressLongitude)
    ? { latitude: addressLatitude, longitude: addressLongitude }
    : null;
}

function distanceBetweenWarehouseAndRequest(warehouse, request) {
  const origin = warehouseCoordinates(warehouse);
  const destination = requestCoordinates(request);
  if (!origin || !destination) return null;

  return haversineKm(
    origin.latitude,
    origin.longitude,
    destination.latitude,
    destination.longitude,
  );
}

function addDistanceToRequests(requests, warehouse) {
  if (!Array.isArray(requests)) return [];
  return requests.map((request) => ({
    ...request,
    distancia_km: distanceBetweenWarehouseAndRequest(warehouse, request),
  }));
}

module.exports = {
  parseCoordinate,
  warehouseCoordinates,
  requestCoordinates,
  distanceBetweenWarehouseAndRequest,
  addDistanceToRequests,
};
