import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/api_error_handler.dart';
import '../models/almacen.dart';
import 'api_client.dart';
import 'almacen_repository.dart';

class AlmacenService {
  final ApiClient _apiClient = ApiClient();
  final AlmacenRepository? _repository;

  AlmacenService([this._repository]);

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
      // Offline: intentar obtener del caché local
      if (_repository != null) {
        final local = await _repository.obtenerPerfilAlmacenLocal();
        if (local != null) return true;
      }
      // TimeoutException y SocketException se traducen a mensajes amigables.
      throw ApiErrorHandler.fromException(e);
    }

    if (response.statusCode == 200) {
      // Guardar en caché local
      if (_repository != null) {
        try {
          final data = json.decode(response.body);
          await _repository.guardarPerfilAlmacen(Almacen.fromJson(data));
        } catch (_) {}
      }
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
      if (_repository != null) {
        await _repository.guardarPerfilAlmacen(Almacen.fromJson(response));
      }
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
      // Intentar red
      final response = await _apiClient.get('/warehouse/my-warehouse');
      if (response.isNotEmpty && _repository != null) {
        await _repository.guardarPerfilAlmacen(Almacen.fromJson(response));
      }
      return response.isNotEmpty ? response : null;
    } on ApiException catch (e) {
      // Si falla por red/timeout, intentar local
      if (e.statusCode == null || e.statusCode == 0 || e.statusCode == 504) {
        if (_repository != null) {
          final local = await _repository.obtenerPerfilAlmacenLocal();
          return local?.toJson();
        }
      }
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
      if (_repository != null) {
        await _repository.guardarPerfilAlmacen(Almacen.fromJson(response));
      }
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
