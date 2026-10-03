import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:repuestosya/utils/sentry_config.dart';

/// Filtro `beforeSend` de Sentry (Fase 8 de docs/TESTING.md): ningún evento
/// debe salir del dispositivo con el header Authorization ni con datos
/// personales (email, cédula/RUC, teléfono, contraseña, tokens).
void main() {
  test('elimina el header Authorization del request', () async {
    final event = SentryEvent(
      request: SentryRequest(
        url: 'https://api.test/requests',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer token-secreto-123',
          'Accept': 'application/json',
        },
        data: {'pieza_nombre': 'Filtro'},
      ),
    );

    final filtrado = await SentryConfig.filtrarEventoParaTest(event);

    final headers = filtrado!.request!.headers;
    expect(headers.containsKey('Authorization'), isFalse);
    expect(headers.containsKey('authorization'), isFalse);
    expect(headers['Content-Type'], 'application/json'); // no PII se conserva
    expect(filtrado.request!.data, {'pieza_nombre': 'Filtro'});
  });

  test('elimina campos personales de request.data y extra', () async {
    final event = SentryEvent(
      request: SentryRequest(
        url: 'https://api.test/auth/login',
        method: 'POST',
        headers: const {'Content-Type': 'application/json'},
        data: {
          'email': 'cliente@example.com',
          'password': 'secreto',
          'pieza_nombre': 'Filtro',
        },
      ),
      // ignore: deprecated_member_use
      extra: {
        'ruc': '1712345678001',
        'cedula': '1712345678',
        'telefono': '0999999999',
        'trace': 'ok',
      },
    );

    final filtrado = await SentryConfig.filtrarEventoParaTest(event);

    final data = filtrado!.request!.data as Map;
    expect(data.containsKey('email'), isFalse);
    expect(data.containsKey('password'), isFalse);
    expect(data['pieza_nombre'], 'Filtro');

    // ignore: deprecated_member_use
    final extra = filtrado.extra!;
    expect(extra.containsKey('ruc'), isFalse);
    expect(extra.containsKey('cedula'), isFalse);
    expect(extra.containsKey('telefono'), isFalse);
    expect(extra['trace'], 'ok');
  });

  test('el usuario conserva SOLO el id interno (nunca el email)', () async {
    final event = SentryEvent(
      user: SentryUser(id: 'uuid-interno-1', email: 'cliente@example.com'),
    );

    final filtrado = await SentryConfig.filtrarEventoParaTest(event);

    expect(filtrado!.user!.id, 'uuid-interno-1');
    expect(filtrado.user!.email, isNull);
  });

  test('evento sin datos personales pasa intacto', () async {
    final event = SentryEvent(
      message: SentryMessage('ok'),
      // ignore: deprecated_member_use
      extra: {'codigo': 42},
    );

    final filtrado = await SentryConfig.filtrarEventoParaTest(event);

    expect(filtrado, isNotNull);
    // ignore: deprecated_member_use
    expect(filtrado!.extra, {'codigo': 42});
  });

  test(
    'breadcrumb: elimina claves prohibidas del data y conserva el resto',
    () {
      final breadcrumb = Breadcrumb(
        message: 'POST /api/auth/login',
        type: 'http',
        data: {
          'url': 'https://api.test/auth/login',
          'status_code': 200,
          'email': 'cliente@example.com',
          'token': 'eyJ-secreto',
        },
      );

      final filtrado = SentryConfig.filtrarBreadcrumbParaTest(breadcrumb);

      expect(filtrado, isNotNull);
      final data = filtrado!.data!;
      expect(data.containsKey('email'), isFalse);
      expect(data.containsKey('token'), isFalse);
      expect(data['url'], 'https://api.test/auth/login');
      expect(data['status_code'], 200);
    },
  );

  test('breadcrumb: redacta emails y JWTs del mensaje', () {
    final breadcrumb = Breadcrumb(
      message:
          'Login de cliente@example.com con token eyJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJzdXBhYmFzZSJ9.firma-falsa-123',
    );

    final filtrado = SentryConfig.filtrarBreadcrumbParaTest(breadcrumb);

    expect(filtrado!.message, isNot(contains('cliente@example.com')));
    expect(filtrado.message, isNot(contains('eyJhbGciOiJIUzI1NiJ9')));
    expect(filtrado.message, contains('[EMAIL]'));
    expect(filtrado.message, contains('[TOKEN]'));
  });

  test('breadcrumb: mensaje sin datos personales pasa intacto', () {
    final breadcrumb = Breadcrumb(message: 'Carga de catálogo OK');

    final filtrado = SentryConfig.filtrarBreadcrumbParaTest(breadcrumb);

    expect(filtrado!.message, 'Carga de catálogo OK');
  });
}
