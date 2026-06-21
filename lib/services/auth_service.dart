import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Registro de usuario con correo y contraseña
  Future<AuthResponse> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      throw Exception('Error al registrar usuario: $e');
    }
  }

  // Inicio de sesión con correo y contraseña
  Future<AuthResponse> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      throw Exception('Error al iniciar sesión: $e');
    }
  }

  // Cerrar sesión
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Error al cerrar sesión: $e');
    }
  }

  // Obtener el usuario actual
  User? get currentUser => _supabase.auth.currentUser;

  // Verificar si hay un usuario autenticado
  bool get isAuthenticated => currentUser != null;

  // Escuchar cambios en el estado de autenticación
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Recuperar contraseña
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw Exception('Error al enviar correo de recuperación: $e');
    }
  }
}
