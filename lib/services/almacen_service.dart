import 'package:http/http.dart' as http;
import '../utils/api_error_handler.dart';
import 'api_client.dart';

class AlmacenService {
  final ApiClient _apiClient = ApiClient();

  /// Verifica si el usuario autenticado (rol almacen) tiene un perfil de
  /// almacén creado, llamando a `GET /warehouse/my-warehouse`.
  ///
  /// Interpretación del status code:
  /// - **200**: el perfil existe → devuelve `true`.
  /// - **404**: el backend responde `{ error: 'Warehouse not found for this user' }`
  ///   → el usuario aún no completó su perfil comercial → devuelve `false`.
  /// - **otros (401/403/500/timeout/red)**: lanza una [ApiException] con
  ///   mensaje amigable (statusCode preservado) para que la UI la muestre
  ///   como error controlado (no debe confundirse con "perfil no existe").
  ///
  /// Esta es la validación centralizada que usan tanto el flujo post-login
  /// (`LoginPage`) como la autocheck de `WarehouseDashboard` al inicio.
  Future<bool> hasWarehouseProfile() async {
    final token = _apiClient.token;
    if (token == null) {
      throw ApiException(
        'Tu sesión expiró. Inicia sesión nuevamente.',
        statusCode: 401,
        technicalMessage: 'No hay token de autenticación',
      );
    }

    final uri = Uri.parse('${ApiClient.baseUrl}/warehouse/my-warehouse');
    final http.Response response;
    try {
      response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));
    } on Exception catch (e) {
      // TimeoutException y SocketException se traducen a mensajes amigables.
      throw ApiErrorHandler.fromException(e);
    }

    if (response.statusCode == 200) {
      return true;
    }
    if (response.statusCode == 404) {
      // 404 = señal de negocio: el perfil de almacén aún no existe.
      // No se traduce como error: el caller lo trata como `false`.
      return false;
    }
    // Cualquier otro status code se propaga como ApiException amigable.
    throw ApiErrorHandler.fromResponse(response);
  }

  // Crear un nuevo almacén
  Future<Map<String, dynamic>> crearAlmacen(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post(
        '/warehouses',
        body: data,
        requireAuth: true,
      );
      return response;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        ApiErrorHandler.defaultMessage,
        technicalMessage: 'crearAlmacen: $e',
      );
    }
  }

  // Obtener almacén por ID del encargado
  Future<Map<String, dynamic>?> obtenerAlmacenPorEncargado(
    String encargadoId,
  ) async {
    try {
      final response = await _apiClient.get(
        '/warehouses/encargado/$encargadoId',
      );
      return response.isNotEmpty ? response : null;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        ApiErrorHandler.defaultMessage,
        technicalMessage: 'obtenerAlmacenPorEncargado: $e',
      );
    }
  }

  // Obtener el almacén asociado al usuario actual
  Future<Map<String, dynamic>?> obtenerMiAlmacen() async {
    try {
      // Estandarizado a /warehouses/my-warehouse para consistencia
      final response = await _apiClient.get('/warehouse/my-warehouse');
      return response.isNotEmpty ? response : null;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        ApiErrorHandler.defaultMessage,
        technicalMessage: 'obtenerMiAlmacen: $e',
      );
    }
  }

  // Actualizar almacén existente
  Future<Map<String, dynamic>> actualizarAlmacen(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _apiClient.put(
        '/warehouses/$id',
        body: data,
        requireAuth: true,
      );
      return response;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        ApiErrorHandler.defaultMessage,
        technicalMessage: 'actualizarAlmacen: $e',
      );
    }
  }
}
