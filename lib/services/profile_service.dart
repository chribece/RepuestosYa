import '../utils/app_logger.dart';
import 'api_client.dart';

class ProfileService {
  final ApiClient _apiClient = ApiClient();

  // Obtener el rol del usuario desde la tabla profiles
  Future<String?> getUserRole(String userId) async {
    try {
      final response = await _apiClient.get('/profile');
      return response['rol'] as String?;
    } catch (e) {
      AppLogger.error(
        'Error al obtener el rol del usuario: $e',
        name: 'ProfileService',
        error: e,
      );
      return null;
    }
  }

  // Obtener el perfil completo del usuario
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await _apiClient.get('/profile');
      return response;
    } catch (e) {
      AppLogger.error(
        'Error al obtener el perfil del usuario: $e',
        name: 'ProfileService',
        error: e,
      );
      return null;
    }
  }

  // Actualizar el perfil del usuario
  Future<Map<String, dynamic>?> updateProfile({
    String? nombreCompleto,
    String? telefono,
    String? avatarUrl,
  }) async {
    try {
      final response = await _apiClient.put(
        '/profile',
        body: {
          'nombre_completo': ?nombreCompleto,
          'telefono': ?telefono,
          'avatar_url': ?avatarUrl,
        },
      );
      return response;
    } catch (e) {
      AppLogger.error(
        'Error al actualizar el perfil del usuario: $e',
        name: 'ProfileService',
        error: e,
      );
      return null;
    }
  }
}
