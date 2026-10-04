import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/coordinacion_entrega.dart';

/// Caché local de los datos de coordinación de entrega por solicitud: permite
/// reabrir la pantalla "Éxito y Coordinación de Entrega" desde una solicitud
/// ACEPTADA y seguir mostrando el contacto del almacén sin conexión (se
/// persiste justo después de aceptar, cuando la respuesta del servidor aún
/// está disponible).
class CoordinacionEntregaCache {
  CoordinacionEntregaCache(this._prefs);

  static const String _prefijo = 'coordinacion_entrega_';

  final SharedPreferences _prefs;

  /// Carga la instancia con las preferencias compartidas.
  static Future<CoordinacionEntregaCache> instancia() async {
    return CoordinacionEntregaCache(await SharedPreferences.getInstance());
  }

  Future<void> guardar(DatosCoordinacionEntrega datos) async {
    if (datos.solicitudId.isEmpty) return;
    await _prefs.setString(
      '$_prefijo${datos.solicitudId}',
      jsonEncode(datos.toJson()),
    );
  }

  DatosCoordinacionEntrega? leer(String solicitudId) {
    final raw = _prefs.getString('$_prefijo$solicitudId');
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return DatosCoordinacionEntrega.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }
}
