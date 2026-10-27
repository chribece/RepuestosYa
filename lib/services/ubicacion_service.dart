import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Estado del intento de obtener la ubicación del dispositivo.
enum UbicacionEstado {
  /// Coordenadas obtenidas correctamente.
  ok,

  /// El usuario denegó el permiso (puede reintentarse).
  permisoDenegado,

  /// Permiso denegado de forma permanente: solo se puede habilitar desde
  /// los Ajustes del sistema (flujo de degradación controlada).
  permisoDenegadoPermanente,

  /// El GPS/servicio de ubicación está apagado en el dispositivo.
  gpsApagado,

  /// No se pudo obtener una fijación GPS (sin señal, timeout, etc.).
  noDisponible,

  /// El usuario canceló el flujo (p. ej. declinó el rationale previo): la
  /// acción se cancela sin error y sin disparar el permiso nativo.
  cancelado,
}

/// Resultado del intento de obtener la ubicación.
class UbicacionResultado {
  const UbicacionResultado({
    required this.estado,
    this.latitude,
    this.longitude,
    this.mensaje,
    this.esUltimaUbicacionConocida = false,
  });

  const UbicacionResultado.ok(
    this.latitude,
    this.longitude, {
    this.mensaje,
    this.esUltimaUbicacionConocida = false,
  }) : estado = UbicacionEstado.ok;

  final UbicacionEstado estado;
  final double? latitude;
  final double? longitude;
  final String? mensaje;
  final bool esUltimaUbicacionConocida;

  bool get disponible =>
      estado == UbicacionEstado.ok && latitude != null && longitude != null;

  bool get esFallbackManual => !disponible;
}

/// Servicio de ubicación del dispositivo (GPS).
///
/// Obtiene una fijación precisa con un límite estricto y, si vence, intenta
/// recuperar la última posición conocida antes de degradar a ingreso manual.
class UbicacionService {
  static const int maxIntentos = 1;
  static const Duration _timeoutFijacion = Duration(seconds: 8);
  static const Duration _timeoutUltimaUbicacion = Duration(seconds: 2);
  static const Duration _timeoutServicioUbicacion = Duration(seconds: 3);

  /// Intenta obtener una posición actual precisa. Si vence el timeout, intenta
  /// usar la última posición conocida; [intentos] se conserva por compatibilidad
  /// y cualquier valor positivo ejecuta una sola fijación acotada.
  Future<UbicacionResultado> obtenerUbicacion({
    int intentos = maxIntentos,
  }) async {
    if (intentos <= 0) {
      return const UbicacionResultado(
        estado: UbicacionEstado.noDisponible,
        mensaje: 'Puedes ingresar la dirección manualmente.',
      );
    }

    try {
      final servicioActivo = await Geolocator.isLocationServiceEnabled()
          .timeout(_timeoutServicioUbicacion);
      if (!servicioActivo) {
        return const UbicacionResultado(
          estado: UbicacionEstado.gpsApagado,
          mensaje: 'El GPS del dispositivo está apagado.',
        );
      }

      var permiso = await Geolocator.checkPermission();

      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }

      if (permiso == LocationPermission.denied) {
        // Un segundo intento de solicitud (el sistema puede mostrar de nuevo
        // el diálogo nativo si el usuario aún no eligió "no volver a preguntar").
        permiso = await Geolocator.requestPermission();
      }

      if (permiso == LocationPermission.denied) {
        return const UbicacionResultado(
          estado: UbicacionEstado.permisoDenegado,
          mensaje: 'Permiso de ubicación denegado.',
        );
      }

      if (permiso == LocationPermission.deniedForever) {
        return const UbicacionResultado(
          estado: UbicacionEstado.permisoDenegadoPermanente,
          mensaje:
              'El permiso de ubicación fue denegado permanentemente. Habilítalo desde los Ajustes del dispositivo.',
        );
      }

      if (permiso == LocationPermission.unableToDetermine) {
        return const UbicacionResultado(
          estado: UbicacionEstado.noDisponible,
          mensaje: 'No se pudo determinar el estado del permiso de ubicación.',
        );
      }

      return await obtenerConFallbackUltimaUbicacion(
        obtenerActual: () async {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: _timeoutFijacion,
            ),
          );
          return UbicacionResultado.ok(position.latitude, position.longitude);
        },
        obtenerUltima: () async {
          final position = await Geolocator.getLastKnownPosition().timeout(
            _timeoutUltimaUbicacion,
          );
          if (position == null) return null;
          return UbicacionResultado.ok(position.latitude, position.longitude);
        },
      );
    } on LocationServiceDisabledException {
      return const UbicacionResultado(
        estado: UbicacionEstado.gpsApagado,
        mensaje: 'El GPS del dispositivo está apagado.',
      );
    } catch (_) {
      return UbicacionResultado(
        estado: UbicacionEstado.noDisponible,
        mensaje:
            'No se pudo obtener la ubicación. Puedes ingresarla manualmente.',
      );
    }
  }

  /// Limita la fijación precisa y, si tarda demasiado, intenta usar el último
  /// punto conocido. El timeout de este fallback también está acotado.
  @visibleForTesting
  static Future<UbicacionResultado> obtenerConFallbackUltimaUbicacion({
    required Future<UbicacionResultado> Function() obtenerActual,
    required Future<UbicacionResultado?> Function() obtenerUltima,
    Duration timeLimit = _timeoutFijacion,
    Duration timeoutUltima = _timeoutUltimaUbicacion,
  }) async {
    try {
      return await obtenerActual().timeout(timeLimit);
    } on TimeoutException {
      try {
        final ultima = await obtenerUltima().timeout(timeoutUltima);
        if (ultima?.disponible == true) {
          return UbicacionResultado.ok(
            ultima!.latitude!,
            ultima.longitude!,
            esUltimaUbicacionConocida: true,
            mensaje:
                'El GPS tardó en responder; usamos tu última ubicación conocida. Revisa el pin.',
          );
        }
      } catch (_) {
        // Si el último punto también tarda o falla, se degrada a manual.
      }
      return const UbicacionResultado(
        estado: UbicacionEstado.noDisponible,
        mensaje:
            'No pudimos obtener tu ubicación. Puedes ingresar la dirección manualmente.',
      );
    }
  }

  /// Alias semántico de [obtenerUbicacion] usado por el selector visual de
  /// ubicación ("Nueva dirección"). Reutiliza toda la lógica de permisos y
  /// fijación existente; no duplica nada.
  Future<UbicacionResultado> resolveLocation({int intentos = maxIntentos}) =>
      obtenerUbicacion(intentos: intentos);

  /// Abre los Ajustes de la APP para que el usuario habilite el PERMISO de
  /// ubicación (caso `permisoDenegadoPermanente`).
  Future<bool> abrirAjustes() => Geolocator.openAppSettings();

  /// Abre los Ajustes del SISTEMA con el interruptor de Ubicación (caso
  /// `gpsApagado`): es una llamada distinta de `openAppSettings` — no usar
  /// una por la otra.
  Future<bool> abrirAjustesSistema() => Geolocator.openLocationSettings();
}
