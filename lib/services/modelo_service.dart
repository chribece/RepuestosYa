import 'api_client.dart';

class ModeloService {
  final ApiClient _apiClient = ApiClient();

  // Obtener modelos filtrados por marca
  Future<List<Map<String, dynamic>>> getModelosPorMarca(int marcaId) async {
    try {
      final response = await _apiClient.get('/modelos?marcaId=$marcaId', requireAuth: false);
      if (response['exito'] == true && response['datos'] != null) {
        return List<Map<String, dynamic>>.from(response['datos']);
      }
      return [];
    } catch (e) {
      throw Exception('Error al obtener modelos: $e');
    }
  }
}
