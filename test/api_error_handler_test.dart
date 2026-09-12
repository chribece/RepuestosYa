import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:repuestosya/utils/api_error_handler.dart';

void main() {
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

  test('conserva el mapeo de errores de validación 422', () {
    final error = ApiErrorHandler.fromResponse(
      http.Response(
        '{"errors":[{"field":"email","message":"Email inválido"}]}',
        422,
      ),
    );

    expect(ApiErrorHandler.mapValidationErrors(error), {
      'email': 'Email inválido',
    });
  });
}
