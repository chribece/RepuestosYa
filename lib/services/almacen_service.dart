import 'api_client.dart';

class AlmacenService {
  final ApiClient _apiClient = ApiClient();

  // Crear un nuevo almacén
  Future<Map<String, dynamic>> crearAlmacen(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post(
        '/almacenes',
        body: data,
        requireAuth: true,
      );
      return response;
    } catch (e) {
      throw Exception('Error al crear almacén: $e');
    }
  }

  // Obtener almacén por ID del encargado
  Future<Map<String, dynamic>?> obtenerAlmacenPorEncargado(String encargadoId) async {
    try {
      final response = await _apiClient.get('/almacenes/encargado/$encargadoId');
      return response.isNotEmpty ? response : null;
    } catch (e) {
      throw Exception('Error al obtener almacén por encargado: $e');
    }
  }

  // Obtener el almacén asociado al usuario actual
  Future<Map<String, dynamic>?> obtenerMiAlmacen() async {
    try {
      print('DEBUG: Llamando a /almacen/mi-almacen');
      final response = await _apiClient.get('/almacen/mi-almacen');
      print('DEBUG: Response de /almacen/mi-almacen: $response');
      print('DEBUG: Response está vacía? ${response.isEmpty}');
      return response.isNotEmpty ? response : null;
    } catch (e) {
      print('DEBUG: Error en obtenerMiAlmacen: $e');
      throw Exception('Error al obtener almacén: $e');
    }
  }

  // Actualizar almacén existente
  Future<Map<String, dynamic>> actualizarAlmacen(String id, Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.put(
        '/almacenes/$id',
        body: data,
        requireAuth: true,
      );
      return response;
    } catch (e) {
      throw Exception('Error al actualizar almacén: $e');
    }
  }
}
