import 'api_client.dart';

class MarcaService {
  final ApiClient _apiClient = ApiClient();

  // Obtener todas las marcas
  Future<List<Map<String, dynamic>>> getMarcas() async {
    try {
      final response = await _apiClient.get('/brands', requireAuth: false);
      if (response['exito'] == true && response['datos'] != null) {
        return List<Map<String, dynamic>>.from(response['datos']);
      }
      return [];
    } catch (e) {
      throw Exception('Error al obtener marcas: $e');
    }
  }
}
