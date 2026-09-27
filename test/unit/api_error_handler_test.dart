import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:repuestosya/utils/api_error_handler.dart';

void main() {
  group('fromResponse', () {
    test('clasifica errores de parseo como errores de datos', () {
      final error = ApiErrorHandler.fromException(const FormatException());

      expect(error.type, ApiErrorType.data);
      expect(error.message, ApiErrorHandler.dataMessage);
    });

    test('traduce cualquier respuesta 5xx al mensaje de servidor', () {
      final error = ApiErrorHandler.fromResponse(
        http.Response('{"error":"internal"}', 503),
      );

      expect(error.type, ApiErrorType.http);
      expect(error.message, ApiErrorHandler.serverMessage);
    });

    test('401 → mensaje de sesión expirada', () {
      final error = ApiErrorHandler.fromResponse(http.Response('{}', 401));

      expect(error.statusCode, 401);
      expect(error.message, 'Tu sesión expiró. Inicia sesión nuevamente.');
    });

    test('409 → mensaje de registro duplicado', () {
      final error = ApiErrorHandler.fromResponse(http.Response('{}', 409));

      expect(error.message, 'Ya existe un registro con esos datos.');
    });

    test(
      '422 conserva el body completo como técnico para mapValidationErrors',
      () {
        final error = ApiErrorHandler.fromResponse(
          http.Response(
            '{"errors":[{"field":"vehiculo_id","message":"no existe"}]}',
            422,
          ),
        );

        expect(error.technicalMessage, contains('vehiculo_id'));
        expect(error.type, ApiErrorType.http);
      },
    );

    test('body no JSON → técnico queda como "HTTP <code>"', () {
      final error = ApiErrorHandler.fromResponse(
        http.Response('<html>Server Error</html>', 500),
      );

      expect(error.technicalMessage, 'HTTP 500');
    });
  });

  group('mapValidationErrors (422 → campo)', () {
    test('mapea el error 422 de objeto plano al campo', () {
      final error = ApiErrorHandler.fromResponse(
        http.Response(
          '{"field":"ruc","message":"El RUC ya está registrado"}',
          422,
        ),
      );

      expect(ApiErrorHandler.mapValidationErrors(error), {
        'ruc': 'El RUC ya está registrado',
      });
    });

    test(
      'conserva el mapeo de errores de validación 422 (lista normalizada)',
      () {
        final error = ApiErrorHandler.fromResponse(
          http.Response(
            '{"errors":[{"field":"email","message":"Email inválido"}]}',
            422,
          ),
        );

        expect(ApiErrorHandler.mapValidationErrors(error), {
          'email': 'Email inválido',
        });
      },
    );

    test('mapea el formato legacy errores/campo/mensaje', () {
      final error = ApiErrorHandler.fromResponse(
        http.Response(
          '{"errores":[{"campo":"pieza_nombre","mensaje":"Obligatorio"}]}',
          422,
        ),
      );

      expect(ApiErrorHandler.mapValidationErrors(error), {
        'pieza_nombre': 'Obligatorio',
      });
    });

    test('mezcla múltiples errores en un solo mapa', () {
      final error = ApiErrorHandler.fromResponse(
        http.Response(
          '{"errors":['
          '{"field":"email","message":"Email inválido"},'
          '{"field":"password","message":"Muy corta"}'
          ']}',
          422,
        ),
      );

      expect(ApiErrorHandler.mapValidationErrors(error), {
        'email': 'Email inválido',
        'password': 'Muy corta',
      });
    });

    test('error que no es ApiException → mapa vacío', () {
      expect(ApiErrorHandler.mapValidationErrors(Exception('boom')), isEmpty);
    });

    test('ApiException 422 sin técnico → mapa vacío', () {
      const error = ApiException('sin detalle', statusCode: 422);

      expect(ApiErrorHandler.mapValidationErrors(error), isEmpty);
    });

    test('422 con JSON inválido → mapa vacío (no lanza)', () {
      final error = ApiErrorHandler.fromResponse(
        http.Response('<html>no json</html>', 422),
      );

      expect(ApiErrorHandler.mapValidationErrors(error), isEmpty);
    });

    test('422 con errors que no es lista → mapa vacío', () {
      final error = ApiErrorHandler.fromResponse(
        http.Response('{"errors":{"email":"x"}}', 422),
      );

      expect(ApiErrorHandler.mapValidationErrors(error), isEmpty);
    });

    test('422 sin errores → mapa vacío', () {
      final error = ApiErrorHandler.fromResponse(
        http.Response('{"mensaje":"falló"}', 422),
      );

      expect(ApiErrorHandler.mapValidationErrors(error), isEmpty);
    });
  });

  group('fromException', () {
    test('SocketException → error de red con mensaje de conexión', () {
      final error = ApiErrorHandler.fromException(
        const SocketException('Connection refused'),
      );

      expect(error.type, ApiErrorType.network);
      expect(error.message, ApiErrorHandler.noConnectionMessage);
    });

    test('http.ClientException → error de red (heurística)', () {
      final error = ApiErrorHandler.fromException(
        http.ClientException('Connection closed before full header'),
      );

      expect(error.type, ApiErrorType.network);
      expect(error.message, ApiErrorHandler.noConnectionMessage);
    });

    test('TimeoutException → timeout manejable', () {
      final error = ApiErrorHandler.fromException(TimeoutException('t'));

      expect(error.type, ApiErrorType.timeout);
      expect(error.message, ApiErrorHandler.timeoutMessage);
    });

    test('TypeError → error de datos', () {
      final error = ApiErrorHandler.fromException(TypeError());

      expect(error.type, ApiErrorType.data);
      expect(error.message, ApiErrorHandler.dataMessage);
    });

    test('excepción arbitraria → unknown con mensaje genérico', () {
      final error = ApiErrorHandler.fromException(Exception('raro'));

      expect(error.type, ApiErrorType.unknown);
      expect(error.message, ApiErrorHandler.defaultMessage);
    });

    test('ApiException ya traducida se devuelve tal cual', () {
      const original = ApiException('mensaje', statusCode: 422);

      expect(
        identical(ApiErrorHandler.fromException(original), original),
        isTrue,
      );
    });
  });

  group('userMessage', () {
    test('ApiException → devuelve su mensaje amigable directo', () {
      const error = ApiException('Tu sesión expiró.', statusCode: 401);

      expect(ApiErrorHandler.userMessage(error), 'Tu sesión expiró.');
    });

    test(
      'contexto auth: 401 → credenciales inválidas (sin enumerar email)',
      () {
        const error = ApiException('Unauthorized', statusCode: 401);

        expect(
          ApiErrorHandler.userMessage(error, context: ApiErrorContext.auth),
          ApiErrorHandler.invalidCredentialsMessage,
        );
      },
    );

    test('contexto auth: 404 → credenciales inválidas (perfil no existe)', () {
      const error = ApiException('Not found', statusCode: 404);

      expect(
        ApiErrorHandler.userMessage(error, context: ApiErrorContext.auth),
        ApiErrorHandler.invalidCredentialsMessage,
      );
    });

    test('contexto auth: 500 conserva el mensaje propio (solo 400/401/404 '
        'se remapean a credenciales)', () {
      const error = ApiException(
        'Ocurrió un problema en el servidor.',
        statusCode: 500,
      );

      expect(
        ApiErrorHandler.userMessage(error, context: ApiErrorContext.auth),
        'Ocurrió un problema en el servidor.',
      );
    });

    test('contexto session: 401 → sesión expirada', () {
      const error = ApiException('Unauthorized', statusCode: 401);

      expect(
        ApiErrorHandler.userMessage(error, context: ApiErrorContext.session),
        'Tu sesión expiró. Inicia sesión nuevamente.',
      );
    });

    test('contexto session: 403 → sin permisos', () {
      const error = ApiException('Forbidden', statusCode: 403);

      expect(
        ApiErrorHandler.userMessage(error, context: ApiErrorContext.session),
        'No tienes permisos para realizar esta acción.',
      );
    });

    test('quita el prefijo "Exception: " de errores envueltos', () {
      expect(
        ApiErrorHandler.userMessage(Exception('Error al cargar datos')),
        'Error al cargar datos',
      );
    });

    test('texto técnico de red → mensaje genérico (no filtra detalle)', () {
      expect(
        ApiErrorHandler.userMessage(
          Exception('SocketException: Connection refused'),
        ),
        ApiErrorHandler.defaultMessage,
      );
    });

    test('timeout de red puro en contexto auth → mensaje de timeout', () {
      expect(
        ApiErrorHandler.userMessage(
          TimeoutException('t'),
          context: ApiErrorContext.auth,
        ),
        ApiErrorHandler.timeoutMessage,
      );
    });
  });

  group('ApiException', () {
    test('toString devuelve solo el mensaje, nunca el statusCode', () {
      const error = ApiException('Mensaje amigable', statusCode: 500);

      expect(error.toString(), 'Mensaje amigable');
      expect(error.toString(), isNot(contains('500')));
    });
  });
}
