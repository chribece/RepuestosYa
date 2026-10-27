import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Resultado del geocodificado inverso: campos de dirección listos para
/// prellenar el formulario ("Nueva dirección").
class DireccionAutocompletada {
  const DireccionAutocompletada({
    this.ciudad,
    this.callePrincipal,
    this.calleSecundaria,
    this.sector,
    this.referencia,
  });

  final String? ciudad;
  final String? callePrincipal;
  final String? calleSecundaria;
  final String? sector;
  final String? referencia;
}

/// Geocodificado inverso CLIENTE-side vía Nominatim (OpenStreetMap) — el
/// mismo proveedor que el backend usa para el geocoding forward. Sin API key,
/// consistente con las tiles OSM del mapa.
///
/// Swappable: en producción se puede mover a un endpoint propio o a un
/// proveedor con API key (Google/Mapbox) sin romper el resto del flujo —
/// mismo criterio que el geocoding del backend. El resultado solo prellena
/// los campos del formulario; la validación dura sigue siendo la del backend
/// al guardar (forward geocoding restringido a Quito).
class GeocodingService {
  static const Map<String, String> _ciudadesEcuador = {
    'quito': 'Quito',
    'distrito metropolitano de quito': 'Quito',
    'guayaquil': 'Guayaquil',
    'cuenca': 'Cuenca',
    'santo domingo': 'Santo Domingo',
    'santo domingo de los tsachilas': 'Santo Domingo',
    'machala': 'Machala',
    'duran': 'Durán',
    'manta': 'Manta',
    'portoviejo': 'Portoviejo',
    'loja': 'Loja',
    'ambato': 'Ambato',
    'riobamba': 'Riobamba',
    'ibarra': 'Ibarra',
    'esmeraldas': 'Esmeraldas',
    'quevedo': 'Quevedo',
    'milagro': 'Milagro',
    'babahoyo': 'Babahoyo',
    'latacunga': 'Latacunga',
    'tulcan': 'Tulcán',
    'salinas': 'Salinas',
    'santa elena': 'Santa Elena',
    'azogues': 'Azogues',
    'otavalo': 'Otavalo',
    'sangolqui': 'Sangolquí',
    'tena': 'Tena',
    'puyo': 'Puyo',
    'macas': 'Macas',
    'nueva loja': 'Nueva Loja',
    'lago agrio': 'Nueva Loja',
    'cayambe': 'Cayambe',
    'daule': 'Daule',
    'chone': 'Chone',
    'jipijapa': 'Jipijapa',
    'la libertad': 'La Libertad',
    'pasaje': 'Pasaje',
    'ventanas': 'Ventanas',
    'naranjal': 'Naranjal',
    'guaranda': 'Guaranda',
    'zamora': 'Zamora',
    'bahia de caraquez': 'Bahía de Caráquez',
    'huaquillas': 'Huaquillas',
    'catamayo': 'Catamayo',
    'playas': 'Playas',
    'el carmen': 'El Carmen',
    'la troncal': 'La Troncal',
    'samborondon': 'Samborondón',
    'puerto ayora': 'Puerto Ayora',
    'puerto baquerizo moreno': 'Puerto Baquerizo Moreno',
  };
  static const String _reverseUrl =
      'https://nominatim.openstreetmap.org/reverse';
  static const String _userAgent =
      'RepuestosYaApp/1.0 (soporte@repuestosya.com)';
  static const Duration _timeout = Duration(seconds: 8);
  static const List<String> _overpassUrls = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];
  static const double _nearbyRoadRadiusMeters = 50;
  static const Set<String> _nonStreetHighways = {
    'bridleway',
    'corridor',
    'cycleway',
    'footway',
    'path',
    'pedestrian',
    'steps',
    'track',
  };
  static final Map<String, DireccionAutocompletada> _reverseCache = {};
  static final Map<String, String> _nearbyRoadCache = {};

  /// Geocodifica inversamente un punto (lat/lng) y devuelve los campos de
  /// dirección para autocompletar. Devuelve `null` si el punto está fuera de
  /// Ecuador (fuera del alcance actual) o si el servicio falla: en ese caso
  /// el usuario escribe el texto manualmente (degradación silenciosa).
  Future<DireccionAutocompletada?> reverseGeocode({
    required double lat,
    required double lng,
    bool buscarCalleSecundariaCercana = false,
  }) async {
    final cacheKey = '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
    var resultado = _reverseCache[cacheKey];
    if (resultado == null) {
      final uri = Uri.parse(_reverseUrl).replace(
        queryParameters: {
          'format': 'json',
          'lat': lat.toStringAsFixed(6),
          'lon': lng.toStringAsFixed(6),
          'zoom': '18', // nivel de calle
          'accept-language': 'es',
        },
      );

      try {
        final res = await http
            .get(uri, headers: {'User-Agent': _userAgent})
            .timeout(_timeout);
        if (res.statusCode != 200) return null;
        final json = jsonDecode(res.body);
        if (json is! Map<String, dynamic>) return null;
        final address = json['address'];
        if (address is! Map<String, dynamic>) return null;
        resultado = parse(address);
        if (resultado == null) return null;
        _guardarEnCacheReverse(cacheKey, resultado);
      } catch (_) {
        // Sin red, timeout o respuesta inesperada: degradación silenciosa.
        return null;
      }
    }

    if (!buscarCalleSecundariaCercana) return resultado;

    if (esCalleSecundariaValida(resultado.calleSecundaria)) {
      return resultado;
    }

    final calleCercana = await _buscarCalleCercana(
      lat: lat,
      lng: lng,
      callePrincipal: resultado.callePrincipal,
    );
    if (calleCercana == null) return resultado;

    return DireccionAutocompletada(
      ciudad: resultado.ciudad,
      callePrincipal: resultado.callePrincipal,
      calleSecundaria: calleCercana,
      sector: resultado.sector,
      referencia: resultado.referencia ?? resultado.sector,
    );
  }

  static void _guardarEnCacheReverse(
    String key,
    DireccionAutocompletada result,
  ) {
    if (_reverseCache.length >= 100 && !_reverseCache.containsKey(key)) {
      _reverseCache.remove(_reverseCache.keys.first);
    }
    _reverseCache[key] = result;
  }

  Future<String?> _buscarCalleCercana({
    required double lat,
    required double lng,
    required String? callePrincipal,
  }) async {
    final cacheKey =
        'nearby-v2:${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}|'
        '${_normalizarNombreVia(callePrincipal)}';
    if (_nearbyRoadCache.containsKey(cacheKey)) {
      return _nearbyRoadCache[cacheKey];
    }

    // Solo se consulta tras estabilizar/confirmar el pin, no durante cada
    // frame del arrastre.
    final query =
        '[out:json][timeout:5];'
        '('
        'way(around:80,$lat,$lng)["highway"]["name"];'
        'way(around:80,$lat,$lng)["highway"]["name:es"];'
        'way(around:80,$lat,$lng)["highway"]["official_name"];'
        ');'
        'out tags geom;';
    for (final endpoint in _overpassUrls) {
      try {
        final response = await http
            .post(
              Uri.parse(endpoint),
              headers: {'User-Agent': _userAgent},
              body: {'data': query},
            )
            .timeout(const Duration(seconds: 6));
        if (response.statusCode != 200) continue;

        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) continue;
        final road = parseNearbySecondaryRoad(
          decoded,
          lat: lat,
          lng: lng,
          callePrincipal: callePrincipal,
        );
        if (road == null) continue;

        _guardarEnCacheCruces(cacheKey, road);
        return road;
      } catch (_) {
        // Prueba el espejo si el endpoint principal no está disponible.
      }
    }
    return null;
  }

  /// Elige el tramo vial nombrado más próximo al pin, excluyendo la calle
  /// principal y caminos peatonales que no sirven como cruce vehicular.
  @visibleForTesting
  static String? parseNearbySecondaryRoad(
    Map<String, dynamic> response, {
    required double lat,
    required double lng,
    String? callePrincipal,
  }) {
    final elements = response['elements'];
    if (elements is! List) return null;

    final primary = _normalizarNombreVia(callePrincipal);
    ({double bearing, double distance})? primaryMeasure;
    final candidates = <({String name, double bearing, double distance})>[];
    for (final element in elements) {
      if (element is! Map) continue;
      final tags = element['tags'];
      if (tags is! Map ||
          _nonStreetHighways.contains(
            tags['highway']?.toString().toLowerCase(),
          )) {
        continue;
      }

      final name =
          tags['name']?.toString().trim() ??
          tags['name:es']?.toString().trim() ??
          tags['official_name']?.toString().trim() ??
          tags['ref']?.toString().trim();
      if (!esCalleSecundariaValida(name)) continue;
      final roadName = name!.trim();

      final geometry = element['geometry'];
      if (geometry is! List || geometry.length < 2) continue;
      final measure = _measureRoad(geometry, lat: lat, lng: lng);
      if (measure.distance > _nearbyRoadRadiusMeters) continue;

      if (_normalizarNombreVia(roadName) == primary) {
        if (primaryMeasure == null ||
            measure.distance < primaryMeasure.distance) {
          primaryMeasure = measure;
        }
        continue;
      }
      candidates.add((
        name: roadName,
        bearing: measure.bearing,
        distance: measure.distance,
      ));
    }

    if (candidates.isEmpty) return null;
    final crossRoads = primaryMeasure == null
        ? candidates
        : candidates
              .where(
                (candidate) =>
                    _roadAngleDifference(
                      primaryMeasure!.bearing,
                      candidate.bearing,
                    ) >=
                    20 * math.pi / 180,
              )
              .toList();
    if (crossRoads.isEmpty) return null;
    crossRoads.sort((a, b) => a.distance.compareTo(b.distance));
    return crossRoads.first.name;
  }

  static ({double bearing, double distance}) _measureRoad(
    List<dynamic> geometry, {
    required double lat,
    required double lng,
  }) {
    final points = <(double, double)>[];
    for (final point in geometry) {
      if (point is! Map) continue;
      final pointLat = double.tryParse(point['lat']?.toString() ?? '');
      final pointLng = double.tryParse(point['lon']?.toString() ?? '');
      if (pointLat != null && pointLng != null) {
        points.add((pointLat, pointLng));
      }
    }
    if (points.length < 2) {
      return (bearing: 0, distance: double.infinity);
    }

    var nearest = (bearing: 0.0, distance: double.infinity);
    for (var index = 0; index < points.length - 1; index++) {
      final measurement = _measureRoadSegment(
        lat: lat,
        lng: lng,
        start: points[index],
        end: points[index + 1],
      );
      if (measurement.distance < nearest.distance) nearest = measurement;
    }
    return nearest;
  }

  static ({double bearing, double distance}) _measureRoadSegment({
    required double lat,
    required double lng,
    required (double, double) start,
    required (double, double) end,
  }) {
    const earthRadiusMeters = 6371000.0;
    const degreesToRadians = math.pi / 180;
    final referenceLatitude = lat * degreesToRadians;
    final startX =
        (start.$2 - lng) *
        degreesToRadians *
        math.cos(referenceLatitude) *
        earthRadiusMeters;
    final startY = (start.$1 - lat) * degreesToRadians * earthRadiusMeters;
    final endX =
        (end.$2 - lng) *
        degreesToRadians *
        math.cos(referenceLatitude) *
        earthRadiusMeters;
    final endY = (end.$1 - lat) * degreesToRadians * earthRadiusMeters;
    final deltaX = endX - startX;
    final deltaY = endY - startY;
    final lengthSquared = deltaX * deltaX + deltaY * deltaY;
    final projection = lengthSquared == 0
        ? 0.0
        : (-(startX * deltaX + startY * deltaY) / lengthSquared)
              .clamp(0.0, 1.0)
              .toDouble();
    final nearestX = startX + projection * deltaX;
    final nearestY = startY + projection * deltaY;
    return (
      bearing: math.atan2(deltaX, deltaY),
      distance: math.sqrt(nearestX * nearestX + nearestY * nearestY),
    );
  }

  static double _roadAngleDifference(double a, double b) {
    final difference = (a - b).abs() % math.pi;
    return math.min(difference, math.pi - difference);
  }

  static String _normalizarNombreVia(String? name) =>
      name?.trim().toLowerCase() ?? '';

  /// Parsea el bloque `address` de Nominatim (reverse) a campos del
  /// formulario. Solo se autocompleta dentro de Ecuador (alcance actual);
  /// busca cruces/vías alternativas para la calle secundaria y conserva los
  /// barrios y sectores únicamente como referencia.
  @visibleForTesting
  static DireccionAutocompletada? parse(Map<String, dynamic> address) {
    final countryCode = address['country_code']
        ?.toString()
        .toLowerCase()
        .trim();
    if (countryCode != 'ec') return null;

    final roadKeys = [
      'road',
      'street',
      'pedestrian',
      'residential',
      'unclassified',
      'tertiary',
      'secondary',
      'primary',
      'service',
      'living_street',
      'footway',
      'path',
      'cycleway',
      'track',
    ];
    final road = _firstAddressText(address, roadKeys);
    final explicitCrossStreet = _firstAddressText(address, [
      'intersection',
      'crossing',
      'cross_street',
      'cross_street_name',
      'street_2',
      'road_2',
      'secondary_road',
      'junction',
    ], excluding: road);
    final nearbyNamedRoad = _firstAddressText(
      address,
      roadKeys.skip(1),
      excluding: road,
    );
    String? secondaryRoad;
    for (final candidate in [explicitCrossStreet, nearbyNamedRoad]) {
      if (esCalleSecundariaValida(candidate)) {
        secondaryRoad = candidate!.trim();
        break;
      }
    }
    final city = _parseCiudad(address);
    final suburb = address['suburb']?.toString().trim();
    final neighbourhood = address['neighbourhood']?.toString().trim();
    final quarter = address['quarter']?.toString().trim();
    final area = (suburb != null && suburb.isNotEmpty)
        ? suburb
        : (neighbourhood != null && neighbourhood.isNotEmpty)
        ? neighbourhood
        : (quarter != null && quarter.isNotEmpty)
        ? quarter
        : null;
    return DireccionAutocompletada(
      ciudad: city,
      callePrincipal: road,
      calleSecundaria: secondaryRoad,
      sector: area,
      referencia: area,
    );
  }

  static String? _parseCiudad(Map<String, dynamic> address) {
    final zonasNoUrbanas =
        {'city_district', 'suburb', 'neighbourhood', 'quarter', 'residential'}
            .map((key) => address[key]?.toString().trim().toLowerCase())
            .whereType<String>()
            .where((value) => value.isNotEmpty)
            .map(_normalizarTextoGeografico)
            .toSet();

    for (final key in const ['city', 'town', 'village']) {
      final rawCandidate = address[key]?.toString().trim();
      if (rawCandidate == null ||
          zonasNoUrbanas.contains(_normalizarTextoGeografico(rawCandidate))) {
        continue;
      }
      final candidate = ciudadEcuadorValida(rawCandidate);
      if (candidate != null) return candidate;
    }
    return null;
  }

  static String? ciudadEcuadorValida(String? value) {
    final ciudad = value?.trim();
    if (ciudad == null || ciudad.isEmpty) return null;
    final normalized = _normalizarClaveGeografica(ciudad);
    if (RegExp(
      r'\b(sector|barrio|urbanizacion|lotizacion|conjunto|ciudadela)\b',
    ).hasMatch(normalized)) {
      return null;
    }
    return _ciudadesEcuador[normalized];
  }

  static bool esCalleSecundariaValida(String? value) {
    final calle = value?.trim();
    if (calle == null || calle.isEmpty) return false;
    final normalized = _normalizarTextoGeografico(calle);
    return !RegExp(
      r'\b(sector|barrio|urbanizacion|lotizacion)\b',
    ).hasMatch(normalized);
  }

  static String _normalizarTextoGeografico(String value) => value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ñ', 'n');

  static String _normalizarClaveGeografica(String value) =>
      _normalizarTextoGeografico(
        value,
      ).replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  static void _guardarEnCacheCruces(String key, String road) {
    if (_nearbyRoadCache.length >= 100 && !_nearbyRoadCache.containsKey(key)) {
      _nearbyRoadCache.remove(_nearbyRoadCache.keys.first);
    }
    _nearbyRoadCache[key] = road;
  }

  static String? _firstAddressText(
    Map<String, dynamic> address,
    Iterable<String> keys, {
    String? excluding,
  }) {
    for (final key in keys) {
      final value = address[key]?.toString().trim();
      if (value != null &&
          value.isNotEmpty &&
          value.toLowerCase() != excluding?.toLowerCase()) {
        return value;
      }
    }
    return null;
  }
}
