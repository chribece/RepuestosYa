import 'api_client.dart';

class ProfileService {
  final ApiClient _apiClient = ApiClient();

  // Obtener el rol del usuario desde la tabla profiles
  Future<String?> getUserRole(String userId) async {
    try {
      final response = await _apiClient.get('/profile');
      return response['rol'] as String?;
    } catch (e) {
      print('Error al obtener el rol del usuario: $e');
      return null;
    }
  }

  // Obtener el perfil completo del usuario
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await _apiClient.get('/profile');
      return response;
    } catch (e) {
      print('Error al obtener el perfil del usuario: $e');
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
          if (nombreCompleto != null) 'nombre_completo': nombreCompleto,
          if (telefono != null) 'telefono': telefono,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
        },
      );
      return response;
    } catch (e) {
      print('Error al actualizar el perfil del usuario: $e');
      return null;
    }
  }
}
