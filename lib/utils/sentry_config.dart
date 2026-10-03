import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sentry_flutter/sentry_flutter.dart';

import '../config/app_config.dart';
import 'app_logger.dart';

/// Configuración de Sentry (Fase 8 de docs/TESTING.md).
///
/// El DSN se inyecta con `--dart-define=SENTRY_DSN=...` (nunca hardcodeado).
/// Sin DSN la app arranca igual (Sentry desactivado, sin red).
///
/// Filtros obligatorios antes de que cualquier evento salga del dispositivo:
/// - Header `Authorization` (token de sesión) removido.
/// - Campos personales (email, cédula/RUC, teléfono, contraseña, tokens)
///   removidos de request.data y event.extra.
/// - `user.id` = identificador interno (UUID del usuario en la base); nunca
///   correo ni cédula.
class SentryConfig {
  const SentryConfig._();

  /// Release/dist alineado con `pubspec.yaml` (1.0.0+1). Se puede inyectar
  /// con `--dart-define=APP_VERSION=1.0.0+1` (CI); el default debe
  /// sincronizarse con `pubspec.yaml` al distribuir (ver docs/ambientes.md).
  static final String release =
      'repuestosya@${String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0+1')}';

  /// Claves que nunca deben salir del dispositivo (case-insensitive).
  @visibleForTesting
  static const Set<String> camposProhibidos = {
    'authorization',
    'password',
    'pass',
    'token',
    'refresh_token',
    'refreshToken',
    'email',
    'cedula',
    'ruc',
    'telefono',
    'phone',
    'nombre_completo',
    'nombreCompleto',
  };

  /// Inicializa Sentry si hay DSN vía --dart-define; si no, no-op.
  static Future<void> init() async {
    const dsn = String.fromEnvironment('SENTRY_DSN');
    if (dsn.isEmpty) {
      AppLogger.info(
        'Sentry desactivado: no hay SENTRY_DSN (--dart-define)',
        name: 'SentryConfig',
      );
      return;
    }

    await SentryFlutter.init((options) {
      options
        ..dsn = dsn
        ..environment = AppConfig.environment
        ..release = release
        // Nunca enviar PII recogida por el SDK (datos del dispositivo).
        ..sendDefaultPii = false
        // Capa gratuita: muestreo de trazas bajo para no disparar el límite.
        ..tracesSampleRate = 0.1
        // Diagnóstico opcional: logs del SDK (envelope enviado, event id)
        // con --dart-define=SENTRY_DEBUG=true. Off por defecto.
        ..debug = const bool.fromEnvironment('SENTRY_DEBUG')
        ..beforeSend = _filtrarEvento
        ..beforeBreadcrumb = _filtrarBreadcrumb;
    });
    AppLogger.info('Sentry inicializado', name: 'SentryConfig');
  }

  /// Asocia el usuario actual al scope con su identificador INTERNO (UUID).
  /// [userId] null limpia el usuario.
  static void setUsuario(String? userId) {
    Sentry.configureScope((scope) {
      unawaited(scope.setUser(userId == null ? null : SentryUser(id: userId)));
    });
  }

  /// Filtro previo al envío (beforeSend): elimina Authorization y datos
  /// personales. Devuelve el evento filtrado.
  static FutureOr<SentryEvent?> _filtrarEvento(SentryEvent event, Hint hint) {
    final request = event.request;
    if (request != null) {
      final headers = <String, String>{
        for (final e in request.headers.entries)
          if (!_esCampoProhibido(e.key)) e.key: e.value,
      };

      // `request.data` devuelve una copia inmutable: se reconstruye el
      // request con los datos filtrados.
      final data = request.data;
      dynamic nuevoData = data;
      if (data is Map) {
        nuevoData = {
          for (final e in data.entries)
            if (!_esCampoProhibido(e.key.toString())) e.key: e.value,
        };
      }

      event.request = SentryRequest(
        url: request.url,
        method: request.method,
        queryString: request.queryString,
        cookies: request.cookies,
        fragment: request.fragment,
        apiTarget: request.apiTarget,
        data: nuevoData,
        headers: headers,
      );
    }

    // ignore: deprecated_member_use
    final extra = event.extra;
    if (extra != null) {
      extra.removeWhere((key, _) => _esCampoProhibido(key));
    }

    final user = event.user;
    if (user != null) {
      // Solo se usa el id interno; el correo nunca viaja.
      event.user = SentryUser(id: user.id);
    }

    return event;
  }

  static bool _esCampoProhibido(String key) {
    final lower = key.toLowerCase();
    return camposProhibidos.any((p) => lower == p.toLowerCase());
  }

  // ── Breadcrumbs ─────────────────────────────────────────────────────────

  static final RegExp _emailRegex = RegExp(r'[\w.+-]+@[\w-]+(\.[\w-]+)+');
  static final RegExp _jwtRegex = RegExp(
    r'eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}',
  );

  /// Redacta emails y tokens tipo JWT de cualquier texto.
  static String _sanitizarTexto(String texto) {
    return texto
        .replaceAll(_emailRegex, '[EMAIL]')
        .replaceAll(_jwtRegex, '[TOKEN]');
  }

  static dynamic _sanitizarValor(dynamic value) {
    if (value is String) return _sanitizarTexto(value);
    return value;
  }

  /// Filtro de breadcrumbs (beforeBreadcrumb): elimina claves prohibidas del
  /// `data` y redacta emails/tokens del mensaje. Los breadcrumbs HTTP que
  /// añade el SDK nunca incluyen headers, así que Authorization no llega aquí.
  static Breadcrumb? _filtrarBreadcrumb(Breadcrumb? breadcrumb, Hint hint) {
    if (breadcrumb == null) return null;
    final data = breadcrumb.data;
    if (data != null && data.isNotEmpty) {
      breadcrumb.data = <String, dynamic>{
        for (final e in data.entries)
          if (!_esCampoProhibido(e.key)) e.key: _sanitizarValor(e.value),
      };
    }
    final message = breadcrumb.message;
    if (message != null) {
      breadcrumb.message = _sanitizarTexto(message);
    }
    return breadcrumb;
  }

  /// Puente para tests: expone [SentryConfig._filtrarBreadcrumb] públicamente.
  @visibleForTesting
  static Breadcrumb? filtrarBreadcrumbParaTest(
    Breadcrumb breadcrumb, {
    Hint? hint,
  }) {
    return _filtrarBreadcrumb(breadcrumb, hint ?? Hint());
  }

  /// Puente para tests: expone [SentryConfig._filtrarEvento] públicamente.
  @visibleForTesting
  static FutureOr<SentryEvent?> filtrarEventoParaTest(
    SentryEvent event, {
    Hint? hint,
  }) {
    return _filtrarEvento(event, hint ?? Hint());
  }
}
