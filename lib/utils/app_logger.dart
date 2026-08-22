import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Logger centralizado de la aplicación.
///
/// Reemplaza el uso de `print()` (prohibido por el lint `avoid_print`) y
/// encapsula `dart:developer.log`, que en release queda inerte porque toda la
/// salida se condiciona a [kDebugMode]. Se apoya en `name` para poder filtrar
/// por módulo en DevTools (p. ej. `AuthService`, `WarehouseDashboard`).
class AppLogger {
  const AppLogger._();

  static const String _defaultName = 'RepuestosYa';

  /// Traza de depuración: solo visible en modo debug.
  static void debug(String message, {String? name}) {
    if (!kDebugMode) return;
    developer.log(message, name: name ?? _defaultName, level: 500);
  }

  /// Evento informativo relevante para seguir el flujo de la app.
  static void info(String message, {String? name}) {
    if (!kDebugMode) return;
    developer.log(message, name: name ?? _defaultName, level: 800);
  }

  /// Situación anómala recuperable (respuesta inesperada, dato faltante...).
  static void warning(String message, {String? name}) {
    if (!kDebugMode) return;
    developer.log(message, name: name ?? _defaultName, level: 900);
  }

  /// Error con excepción y stack trace opcionales.
  static void error(
    String message, {
    String? name,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) return;
    developer.log(
      message,
      name: name ?? _defaultName,
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
