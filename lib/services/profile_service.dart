import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Obtener el rol del usuario desde la tabla profiles
  Future<String?> getUserRole(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('rol')
          .eq('id', userId)
          .single();
      
      return response['rol'] as String?;
    } catch (e) {
      // Si el perfil no existe o hay un error, retornar null
      print('Error al obtener el rol del usuario: $e');
      return null;
    }
  }

  // Obtener el perfil completo del usuario
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      
      return response;
    } catch (e) {
      print('Error al obtener el perfil del usuario: $e');
      return null;
    }
  }
}
