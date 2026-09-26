import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Resultado del geocodificado inverso: campos de dirección listos para
/// prellenar el formulario ("Nueva dirección").
class DireccionAutocompletada {
  const DireccionAutocompletada({
    this.callePrincipal,
    this.calleSecundaria,
    this.referencia,
  });

  final String? callePrincipal;
  final String? calleSecundaria;
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
  static const String _reverseUrl =
      'https://nominatim.openstreetmap.org/reverse';
  static const String _userAgent =
      'RepuestosYaApp/1.0 (soporte@repuestosya.com)';
  static const Duration _timeout = Duration(seconds: 8);

  /// Geocodifica inversamente un punto (lat/lng) y devuelve los campos de
  /// dirección para autocompletar. Devuelve `null` si el punto está fuera de
  /// Ecuador (fuera del alcance actual) o si el servicio falla: en ese caso
  /// el usuario escribe el texto manualmente (degradación silenciosa).
  Future<DireccionAutocompletada?> reverseGeocode({
    required double lat,
    required double lng,
  }) async {
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
      return parse(address);
    } catch (_) {
      // Sin red, timeout o respuesta inesperada: degradación silenciosa.
      return null;
    }
  }

  /// Parsea el bloque `address` de Nominatim (reverse) a campos del
  /// formulario. Solo se autocompleta dentro de Ecuador (alcance actual);
  /// `road` → calle principal; `suburb`/`neighbourhood` → referencia.
  @visibleForTesting
  static DireccionAutocompletada? parse(Map<String, dynamic> address) {
    final countryCode = address['country_code']
        ?.toString()
        .toLowerCase()
        .trim();
    if (countryCode != 'ec') return null;

    final road = address['road']?.toString().trim();
    final suburb = address['suburb']?.toString().trim();
    final neighbourhood = address['neighbourhood']?.toString().trim();
    final area = (suburb != null && suburb.isNotEmpty)
        ? suburb
        : (neighbourhood != null && neighbourhood.isNotEmpty)
        ? neighbourhood
        : null;

    return DireccionAutocompletada(
      callePrincipal: (road != null && road.isNotEmpty) ? road : null,
      // Una respuesta reverse puntual no entrega la intersección; el usuario
      // completa la calle secundaria si existe.
      calleSecundaria: null,
      referencia: (area != null && area.isNotEmpty) ? area : null,
    );
  }
}
