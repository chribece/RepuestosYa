import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:repuestosya/services/api_client.dart';
import 'package:repuestosya/services/solicitud_service.dart';
import 'package:repuestosya/utils/api_error_handler.dart';

/// Contrato de `SolicitudService.cancelarSolicitud` (Parte 4 del flujo de
/// cancelación): PATCH /requests/:id/status con estado 'cancelada'. Verifica
/// que los errores de negocio (409/422) propaguen el mensaje legible del
/// servidor tal cual — la app lo muestra como SnackBar sin traducir a un
/// error genérico.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ApiClient api;

  setUp(() {
    api = ApiClient();
    api.tokenForTesting = 'token-cliente';
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

  test('200: hace PATCH /requests/:id/status con estado cancelada', () async {
    http.Request? peticion;
    api.clientForTesting = MockClient((request) async {
      peticion = request;
      return http.Response('{"id":"srv-1","estado":"cancelada"}', 200);
    });

    final respuesta = await SolicitudService().cancelarSolicitud('srv-1');

    expect(peticion!.method, 'PATCH');
    expect(peticion!.url.path, endsWith('/requests/srv-1/status'));
    expect(peticion!.body, contains('"cancelada"'));
    expect(respuesta['estado'], 'cancelada');
  });

  test(
    '409: propaga el mensaje legible del servidor, no uno genérico',
    () async {
      api.clientForTesting = MockClient(
        (request) async => http.Response(
          '{"error":"La solicitud ya fue respondida por un almacén"}',
          409,
        ),
      );

      await expectLater(
        SolicitudService().cancelarSolicitud('srv-1'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having(
                (e) => e.message,
                'message',
                'La solicitud ya fue respondida por un almacén',
              ),
        ),
      );
    },
  );

  test(
    '422: propaga el mensaje del servidor con el statusCode original',
    () async {
      api.clientForTesting = MockClient(
        (request) async => http.Response(
          '{"error":"La solicitud no es cancelable en su estado actual"}',
          422,
        ),
      );

      await expectLater(
        SolicitudService().cancelarSolicitud('srv-1'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 422)
              .having(
                (e) => e.message,
                'message',
                'La solicitud no es cancelable en su estado actual',
              ),
        ),
      );
    },
  );
}
