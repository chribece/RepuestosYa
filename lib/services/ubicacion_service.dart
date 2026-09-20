import 'dart:async';

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
  });

  const UbicacionResultado.ok(this.latitude, this.longitude)
    : estado = UbicacionEstado.ok,
      mensaje = null;

  final UbicacionEstado estado;
  final double? latitude;
  final double? longitude;
  final String? mensaje;

  bool get disponible =>
      estado == UbicacionEstado.ok && latitude != null && longitude != null;

  bool get esFallbackManual => !disponible;
}

/// Servicio de ubicación del dispositivo (GPS).
///
/// Es el primer origen de coordenadas para la dirección de entrega. Cuando
/// el GPS está inoperable (hardware roto, permiso permanentemente denegado
/// tras agotar el flujo de reintento/Ajustes), el flujo degrada a la
/// introducción manual de la dirección, que el backend geocodifica
/// server-side antes de aceptar el registro: nunca se guarda sin
/// coordenadas de algún origen.
class UbicacionService {
  static const int maxIntentos = 2;
  static const Duration _timeoutFijacion = Duration(seconds: 15);

  /// Intenta obtener la posición actual con el flujo completo de permisos:
  /// solicita el permiso si está denegado y reintenta la fijación hasta
  /// [maxIntentos] veces.
  Future<UbicacionResultado> obtenerUbicacion({
    int intentos = maxIntentos,
  }) async {
    try {
      final servicioActivo = await Geolocator.isLocationServiceEnabled();
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

      for (var i = 0; i < intentos; i++) {
        try {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: _timeoutFijacion,
            ),
          );
          return UbicacionResultado.ok(position.latitude, position.longitude);
        } on TimeoutException {
          // Reintentar la fijación (sin señal o tardó demasiado).
        }
      }

      return const UbicacionResultado(
        estado: UbicacionEstado.noDisponible,
        mensaje:
            'No se pudo obtener una señal GPS. Verifica tu conexión o intenta en un lugar abierto.',
      );
    } on LocationServiceDisabledException {
      return const UbicacionResultado(
        estado: UbicacionEstado.gpsApagado,
        mensaje: 'El GPS del dispositivo está apagado.',
      );
    } catch (e) {
      return UbicacionResultado(
        estado: UbicacionEstado.noDisponible,
        mensaje: 'No se pudo obtener la ubicación: $e',
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
