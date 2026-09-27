import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:repuestosya/services/api_client.dart';
import 'package:repuestosya/utils/api_error_handler.dart';

/// Suite de [ApiClient] contra un doble HTTP (`http.MockClient`, Fase 3 de
/// docs/TESTING.md): 200, 401 con renovación single-flight anti-bucle, 422
/// normalizado y timeout capturado como error manejable. Ninguna llamada
/// toca la red real (pasan en modo avión).
void main() {
  // Necesario para el path 403: `_showForbiddenMessage` accede al
  // rootNavigatorKey global (WidgetsBinding.instance) al leer currentContext.
  TestWidgetsFlutterBinding.ensureInitialized();

  late ApiClient api;

  setUp(() {
    api = ApiClient();
    api.tokenForTesting = 'token-viejo';
    api.onRefreshToken = null;
    api.onUnauthorized = null;
    api.onUnauthorizedAsync = null;
  });

  tearDown(() {
    api.tokenForTesting = null;
    api.onRefreshToken = null;
    api.onUnauthorized = null;
    api.onUnauthorizedAsync = null;
    api.clientForTesting = http.Client();
    api.requestTimeoutForTesting = const Duration(seconds: 10);
  });

  group('200 — respuestas exitosas', () {
    test('get: parsea el JSON y envía el header Authorization', () async {
      http.Request? peticion;
      api.clientForTesting = MockClient((request) async {
        peticion = request;
        return http.Response('{"id":1,"nombre":"Filtro"}', 200);
      });

      final data = await api.get('/requests/1');

      expect(data, {'id': 1, 'nombre': 'Filtro'});
      // AppConfig.baseUrl incluye el prefijo /api.
      expect(peticion!.url.path, endsWith('/requests/1'));
      expect(peticion!.headers['Authorization'], 'Bearer token-viejo');
    });

    test('get: con requireAuth false no envía Authorization', () async {
      http.Request? peticion;
      api.clientForTesting = MockClient((request) async {
        peticion = request;
        return http.Response('{}', 200);
      });

      await api.get('/auth/refresh', requireAuth: false);

      expect(peticion!.headers.containsKey('Authorization'), isFalse);
    });

    test('getList: parsea una lista', () async {
      api.clientForTesting = MockClient(
        (request) async => http.Response('[{"id":1},{"id":2}]', 200),
      );

      final lista = await api.getList('/requests');

      expect(lista, [
        {'id': 1},
        {'id': 2},
      ]);
    });

    test('getList: un objeto (no lista) se envuelve en una lista', () async {
      api.clientForTesting = MockClient(
        (request) async => http.Response('{"id":1}', 200),
      );

      final lista = await api.getList('/requests');

      expect(lista, [
        {'id': 1},
      ]);
    });
  });

  group('401 — renovación de token', () {
    test(
      '401 → refresh → reintenta una sola vez con el token nuevo → 200',
      () async {
        var llamadasData = 0;
        var llamadasRefresh = 0;
        api.onRefreshToken = () async {
          llamadasRefresh++;
          api.tokenForTesting = 'token-nuevo';
          return 'token-nuevo';
        };
        api.clientForTesting = MockClient((request) async {
          if (request.url.path.endsWith('/data')) {
            llamadasData++;
            if (llamadasData == 1) {
              expect(request.headers['Authorization'], 'Bearer token-viejo');
              return http.Response('{"error":"expired"}', 401);
            }
            expect(request.headers['Authorization'], 'Bearer token-nuevo');
            return http.Response('{"ok":true}', 200);
          }
          return http.Response('{"error":"not found"}', 404);
        });

        final result = await api.get('/data');

        expect(result, {'ok': true});
        expect(llamadasData, 2);
        expect(llamadasRefresh, 1);
      },
    );

    test(
      '401 con refresh fallido: limpia sesión, lanza 401 y NO reintenta',
      () async {
        var llamadasData = 0;
        var llamadasRefresh = 0;
        var limpiezas = 0;
        api.onRefreshToken = () async {
          llamadasRefresh++;
          return null; // el backend rechaza el refresh
        };
        api.onUnauthorizedAsync = () async {
          limpiezas++;
        };
        api.clientForTesting = MockClient((request) async {
          llamadasData++;
          return http.Response('{"error":"expired"}', 401);
        });

        await expectLater(
          api.get('/data'),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
          ),
        );

        expect(llamadasData, 1); // sin reintento
        expect(llamadasRefresh, 1);
        expect(limpiezas, 1); // sesión limpiada
      },
    );

    test(
      'anti-bucle: si el reintento vuelve a dar 401 no refresca de nuevo',
      () async {
        var llamadasData = 0;
        var llamadasRefresh = 0;
        var limpiezas = 0;
        api.onRefreshToken = () async {
          llamadasRefresh++;
          api.tokenForTesting = 'token-nuevo';
          return 'token-nuevo';
        };
        api.onUnauthorizedAsync = () async {
          limpiezas++;
        };
        api.clientForTesting = MockClient((request) async {
          llamadasData++;
          return http.Response('{"error":"expired"}', 401); // siempre 401
        });

        await expectLater(api.get('/data'), throwsA(isA<ApiException>()));

        expect(llamadasData, 2); // inicial + reintento, sin tercero
        expect(llamadasRefresh, 1); // un solo refresh
        expect(limpiezas, 1); // sesión limpiada tras el doble 401
      },
    );

    test(
      'single-flight: dos 401 concurrentes comparten un solo refresh',
      () async {
        var llamadasData = 0;
        var llamadasRefresh = 0;
        api.onRefreshToken = () async {
          llamadasRefresh++;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          api.tokenForTesting = 'token-nuevo';
          return 'token-nuevo';
        };
        api.clientForTesting = MockClient((request) async {
          if (request.url.path.endsWith('/data')) {
            llamadasData++;
            return llamadasData <= 2
                ? http.Response('{"error":"expired"}', 401)
                : http.Response('{"ok":true}', 200);
          }
          return http.Response('{"error":"not found"}', 404);
        });

        final resultados = await Future.wait([
          api.get('/data'),
          api.get('/data'),
        ]);

        expect(resultados, [
          {'ok': true},
          {'ok': true},
        ]);
        expect(llamadasRefresh, 1); // un solo refresh para ambos
        expect(llamadasData, 4); // 2 iniciales + 2 reintentos
      },
    );
  });

  group('403 — prohibido sin cierre de sesión', () {
    test(
      '403 → ApiException con mensaje de permisos y NO limpia la sesión',
      () async {
        var limpiezas = 0;
        api.onUnauthorizedAsync = () async {
          limpiezas++;
        };
        api.clientForTesting = MockClient(
          (request) async => http.Response('{"error":"forbidden"}', 403),
        );

        ApiException? capturado;
        try {
          await api.get('/data');
          fail('debió lanzar 403');
        } on ApiException catch (e) {
          capturado = e;
        }

        expect(capturado, isNotNull);
        expect(
          capturado.statusCode,
          403,
          reason: 'technical: ${capturado.technicalMessage}',
        );
        expect(
          capturado.message,
          'No tienes permisos para realizar esta acción.',
        );
        expect(capturado.technicalMessage, 'forbidden');

        // 403 NO dispara el flujo de 401: el usuario permanece autenticado.
        expect(limpiezas, 0);
      },
    );
  });

  group('422 — errores de validación', () {
    test('normaliza el 422 y mapValidationErrors lo asocia al campo', () async {
      api.clientForTesting = MockClient(
        (request) async => http.Response(
          '{"errors":[{"field":"email","message":"Email inválido"}]}',
          422,
        ),
      );

      ApiException? error;
      try {
        await api.post('/requests', body: {'email': 'x'});
        fail('debió lanzar ApiException 422');
      } on ApiException catch (e) {
        error = e;
      }

      expect(error, isNotNull);
      expect(error.statusCode, 422);
      expect(error.type, ApiErrorType.http);
      expect(ApiErrorHandler.mapValidationErrors(error), {
        'email': 'Email inválido',
      });
    });
  });

  group('timeout y reintentos de transporte', () {
    test(
      'timeout: el doble nunca responde → error manejable tipo timeout',
      () async {
        api.requestTimeoutForTesting = const Duration(milliseconds: 200);
        api.clientForTesting = MockClient(
          (request) => Completer<http.Response>().future, // nunca responde
        );

        await expectLater(
          api.post('/requests', body: {}),
          throwsA(
            isA<ApiException>()
                .having((e) => e.type, 'type', ApiErrorType.timeout)
                .having(
                  (e) => e.message,
                  'message',
                  ApiErrorHandler.timeoutMessage,
                ),
          ),
        );
      },
    );

    test('GET con 5xx: reintenta hasta 3 intentos y falla con mensaje de '
        'servidor', () async {
      var llamadas = 0;
      api.clientForTesting = MockClient((request) async {
        llamadas++;
        return http.Response('{"error":"boom"}', 503);
      });

      await expectLater(
        api.get('/data'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            ApiErrorHandler.serverMessage,
          ),
        ),
      );

      expect(llamadas, 3);
    });

    test(
      'POST con 5xx: NO reintenta (las escrituras no son idempotentes)',
      () async {
        var llamadas = 0;
        api.clientForTesting = MockClient((request) async {
          llamadas++;
          return http.Response('{"error":"boom"}', 503);
        });

        await expectLater(
          api.post('/requests', body: {}),
          throwsA(isA<ApiException>()),
        );

        expect(llamadas, 1);
      },
    );
  });
}
