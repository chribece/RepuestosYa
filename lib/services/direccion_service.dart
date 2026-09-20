import '../utils/api_error_handler.dart';
import 'api_client.dart';

class DireccionService {
  final ApiClient _apiClient = ApiClient();

  // Obtener todas las direcciones del usuario
  Future<List<Map<String, dynamic>>> getDirecciones() async {
    try {
      final response = await _apiClient.getList('/addresses');
      return response;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        ApiErrorHandler.defaultMessage,
        technicalMessage: 'getDirecciones: $e',
      );
    }
  }

  // Crear una nueva dirección en el backend (Mapea camelCase a la API).
  // Las coordenadas son opcionales: si no se envían (GPS inoperable), el
  // backend geocodifica la dirección server-side antes de aceptar el registro.
  Future<Map<String, dynamic>> createDireccion({
    required String alias,
    required String callePrincipal,
    String? calleSecundaria,
    String? referencia,
    double? latitude,
    double? longitude,
    String? coordenadasFuente,
  }) async {
    try {
      final data = <String, dynamic>{
        'alias': alias,
        'callePrincipal': callePrincipal,
      };

      if (calleSecundaria != null && calleSecundaria.trim().isNotEmpty) {
        data['calleSecundaria'] = calleSecundaria;
      }
      if (referencia != null && referencia.trim().isNotEmpty) {
        data['referencia'] = referencia;
      }
      if (latitude != null && longitude != null) {
        data['latitude'] = latitude;
        data['longitude'] = longitude;
        data['coordenadasFuente'] = coordenadasFuente ?? 'gps';
      }

      final response = await _apiClient.post('/addresses', body: data);

      return response;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        ApiErrorHandler.defaultMessage,
        technicalMessage: 'createDireccion: $e',
      );
    }
  }

  // Actualizar una dirección existente
  Future<Map<String, dynamic>> updateDireccion({
    required String id,
    String? alias,
    String? callePrincipal,
    String? calleSecundaria,
    String? referencia,
    double? latitude,
    double? longitude,
    String? coordenadasFuente,
  }) async {
    try {
      final data = <String, dynamic>{};

      if (alias != null && alias.trim().isNotEmpty) {
        data['alias'] = alias.trim();
      }
      if (callePrincipal != null && callePrincipal.trim().isNotEmpty) {
        data['callePrincipal'] = callePrincipal.trim();
      }
      if (calleSecundaria != null) {
        data['calleSecundaria'] = calleSecundaria.trim().isEmpty
            ? ''
            : calleSecundaria.trim();
      }
      if (referencia != null) {
        data['referencia'] = referencia.trim().isEmpty ? '' : referencia.trim();
      }
      if (latitude != null && longitude != null) {
        data['latitude'] = latitude;
        data['longitude'] = longitude;
        data['coordenadasFuente'] = coordenadasFuente ?? 'gps';
      }

      final response = await _apiClient.put('/addresses/$id', body: data);

      return response;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        ApiErrorHandler.defaultMessage,
        technicalMessage: 'updateDireccion: $e',
      );
    }
  }

  // Eliminar una dirección
  Future<void> deleteDireccion(String id) async {
    try {
      await _apiClient.delete('/addresses/$id');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        ApiErrorHandler.defaultMessage,
        technicalMessage: 'deleteDireccion: $e',
      );
    }
  }
}
