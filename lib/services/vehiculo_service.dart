import '../utils/api_error_handler.dart';
import 'api_client.dart';

class VehiculoService {
  final ApiClient _apiClient = ApiClient();

  // Obtener todos los vehículos del usuario
  Future<List<Map<String, dynamic>>> getVehiculos() async {
    try {
      final response = await _apiClient.getList('/vehicles');
      return response;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        ApiErrorHandler.defaultMessage,
        technicalMessage: 'getVehiculos: $e',
      );
    }
  }

  // Crear un nuevo vehículo
  Future<Map<String, dynamic>> createVehiculo({
    required int marcaId,
    required int modeloId,
    String? vin,
    String? anio,
    String? patente,
  }) async {
    try {
      final data = <String, dynamic>{'marcaId': marcaId, 'modeloId': modeloId};

      if (vin != null && vin.isNotEmpty) data['vin'] = vin;
      if (anio != null && anio.isNotEmpty) data['anio'] = anio;
      if (patente != null && patente.isNotEmpty) data['patente'] = patente;

      final response = await _apiClient.post('/vehicles', body: data);

      return response;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        ApiErrorHandler.defaultMessage,
        technicalMessage: 'createVehiculo: $e',
      );
    }
  }

  // Actualizar un vehículo
  Future<Map<String, dynamic>> updateVehiculo({
    required String id,
    int? marcaId,
    int? modeloId,
    String? vin,
    String? anio,
    String? patente,
  }) async {
    try {
      final data = <String, dynamic>{};

      if (marcaId != null) data['marcaId'] = marcaId;
      if (modeloId != null) data['modeloId'] = modeloId;
      if (vin != null && vin.isNotEmpty) data['vin'] = vin;
      if (anio != null && anio.isNotEmpty) data['anio'] = anio;
      if (patente != null && patente.isNotEmpty) data['patente'] = patente;

      final response = await _apiClient.put('/vehicles/$id', body: data);

      return response;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        ApiErrorHandler.defaultMessage,
        technicalMessage: 'updateVehiculo: $e',
      );
    }
  }

  // Eliminar un vehículo
  Future<void> deleteVehiculo(String id) async {
    try {
      await _apiClient.delete('/vehicles/$id');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        ApiErrorHandler.defaultMessage,
        technicalMessage: 'deleteVehiculo: $e',
      );
    }
  }
}
