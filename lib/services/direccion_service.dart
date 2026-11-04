import '../utils/api_error_handler.dart';
import 'api_client.dart';
import 'geocoding_service.dart';

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
    String? ciudad,
    String? calleSecundaria,
    String? referencia,
    double? latitude,
    double? longitude,
    String? coordenadasFuente,
  }) async {
    try {
      final campos = GeocodingService.normalizarCamposDireccion(
        ciudad: ciudad ?? '',
        callePrincipal: callePrincipal,
        calleSecundaria: calleSecundaria ?? '',
        referencia: referencia ?? '',
      );
      final data = <String, dynamic>{
        'alias': GeocodingService.limpiarTextoDireccion(alias),
        'callePrincipal': campos.callePrincipal,
      };

      if (campos.ciudad.isNotEmpty) {
        data['ciudad'] = campos.ciudad;
      }
      if (campos.calleSecundaria.isNotEmpty) {
        data['calleSecundaria'] = campos.calleSecundaria;
      }
      if (campos.referencia.isNotEmpty) {
        data['referencia'] = campos.referencia;
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
    String? ciudad,
    String? calleSecundaria,
    String? referencia,
    double? latitude,
    double? longitude,
    String? coordenadasFuente,
  }) async {
    try {
      final campos = GeocodingService.normalizarCamposDireccion(
        ciudad: ciudad ?? '',
        callePrincipal: callePrincipal ?? '',
        calleSecundaria: calleSecundaria ?? '',
        referencia: referencia ?? '',
      );
      final data = <String, dynamic>{};

      final aliasLimpio = GeocodingService.limpiarTextoDireccion(alias);
      if (aliasLimpio.isNotEmpty) {
        data['alias'] = aliasLimpio;
      }
      if (callePrincipal != null && campos.callePrincipal.isNotEmpty) {
        data['callePrincipal'] = campos.callePrincipal;
      }
      if (ciudad != null && campos.ciudad.isNotEmpty) {
        data['ciudad'] = campos.ciudad;
      }
      if (calleSecundaria != null) {
        data['calleSecundaria'] = campos.calleSecundaria;
      }
      if (referencia != null) {
        data['referencia'] = campos.referencia;
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
