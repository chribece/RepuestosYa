import '../utils/api_error_handler.dart';
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
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        ApiErrorHandler.defaultMessage,
        technicalMessage: 'getMarcas: $e',
      );
    }
  }
}
