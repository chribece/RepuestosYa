import 'api_client.dart';

class AlmacenService {
  final ApiClient _apiClient = ApiClient();

  // Obtener el almacén asociado al usuario actual
  Future<Map<String, dynamic>?> obtenerMiAlmacen() async {
    try {
      final response = await _apiClient.get('/almacen/mi-almacen');
      return response.isNotEmpty ? response : null;
    } catch (e) {
      throw Exception('Error al obtener almacén: $e');
    }
  }
}
