import 'api_client.dart';

class AlmacenService {
  final ApiClient _apiClient = ApiClient();

  // Crear un nuevo almacén
  Future<Map<String, dynamic>> crearAlmacen(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post(
        '/warehouses',
        body: data,
        requireAuth: true,
      );
      return response;
    } catch (e) {
      throw Exception('Error al crear almacén: $e');
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
    } catch (e) {
      throw Exception('Error al obtener almacén por encargado: $e');
    }
  }

  // Obtener el almacén asociado al usuario actual
  Future<Map<String, dynamic>?> obtenerMiAlmacen() async {
    try {
      // Estandarizado a /warehouses/my-warehouse para consistencia
      final response = await _apiClient.get('/warehouse/my-warehouse');
      return response.isNotEmpty ? response : null;
    } catch (e) {
      throw Exception('Error al obtener almacén: $e');
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
    } catch (e) {
      throw Exception('Error al actualizar almacén: $e');
    }
  }
}
