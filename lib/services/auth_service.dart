import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/api_error_handler.dart';
import '../utils/app_logger.dart';
import 'api_client.dart';

// Clases compatibles con Supabase para mantener la misma interfaz
class User {
  final String id;
  final String email;
  final String? nombreCompleto;
  final String? rol;

  User({required this.id, required this.email, this.nombreCompleto, this.rol});
}

class AuthResponse {
  final User user;
  final String? token;

  AuthResponse({required this.user, this.token});
}

class AuthState {
  final User? user;

  AuthState({this.user});
}

class AuthService {
  final ApiClient _apiClient = ApiClient();
  User? _currentUser;
  final StreamController<AuthState> _authStateController =
      StreamController<AuthState>.broadcast();

  // Constructor privado para singleton
  AuthService._privateConstructor() {
    _initAuth();
  }

  static final AuthService _instance = AuthService._privateConstructor();
  factory AuthService() => _instance;

  // Inicializar autenticación cargando token
  Future<void> _initAuth() async {
    await _apiClient.init();
    if (_apiClient.isAuthenticated) {
      // Decodificar el JWT para obtener los datos del usuario
      final token = _apiClient.token;
      if (token != null) {
        try {
          final parts = token.split('.');
          if (parts.length == 3) {
            final payload = json.decode(
              utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
            );
            _currentUser = User(
              id: payload['id'] as String,
              email: payload['email'] as String,
              nombreCompleto: payload['nombre_completo'] as String?,
              rol: payload['rol'] as String?,
            );
            _authStateController.add(AuthState(user: _currentUser));
          }
        } catch (e) {
          AppLogger.error(
            'Error decoding token: $e',
            name: 'AuthService',
            error: e,
          );
          // Si hay error al decodificar, limpiar el token
          await _apiClient.clearToken();
        }
      }
    }
  }

  // Registro de usuario con correo y contraseña
  Future<AuthResponse> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? nombreCompleto,
    String? rol,
  }) async {
    try {
      AppLogger.debug(
        'Intentando registrar usuario - Email: $email - Nombre: $nombreCompleto - Rol: $rol',
        name: 'AuthService',
      );

      final response = await _apiClient.post(
        '/auth/register',
        body: {
          'email': email,
          'password': password,
          'nombreCompleto': nombreCompleto,
          'rol': ?rol,
        },
        requireAuth: false,
      );

      AppLogger.info('Registro exitoso', name: 'AuthService');
      final token = response['token'] as String;
      await _apiClient.setToken(token);

      final userData = response['user'] as Map<String, dynamic>;
      _currentUser = User(
        id: userData['id'] as String,
        email: userData['email'] as String,
        nombreCompleto: userData['nombre_completo'] as String?,
        rol: userData['rol'] as String?,
      );

      _authStateController.add(AuthState(user: _currentUser!));

      // Sincronizar sesión con Supabase para permitir subida de imágenes
      await _syncSupabaseSession(email, password);

      return AuthResponse(user: _currentUser!, token: token);
    } on ApiException {
      rethrow;
    } catch (e) {
      AppLogger.error('Error en registro: $e', name: 'AuthService', error: e);
      throw ApiException(
        ApiErrorHandler.defaultMessage,
        technicalMessage: 'signUp: $e',
      );
    }
  }

  // Inicio de sesión con correo y contraseña
  Future<AuthResponse> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post(
        '/auth/login',
        body: {'email': email, 'password': password},
        requireAuth: false,
      );

      final token = response['token'] as String;
      await _apiClient.setToken(token);

      final userData = response['user'] as Map<String, dynamic>;
      _currentUser = User(
        id: userData['id'] as String,
        email: userData['email'] as String,
        nombreCompleto: userData['nombre_completo'] as String?,
        rol: userData['rol'] as String?,
      );

      _authStateController.add(AuthState(user: _currentUser));

      // Sincronizar sesión con Supabase para permitir subida de imágenes
      await _syncSupabaseSession(email, password);

      return AuthResponse(user: _currentUser!, token: token);
    } on ApiException {
      rethrow;
    } catch (e) {
      AppLogger.error('Error en login: $e', name: 'AuthService', error: e);
      throw ApiException(
        ApiErrorHandler.defaultMessage,
        technicalMessage: 'signIn: $e',
      );
    }
  }

  // Sincronizar sesión con Supabase para permitir subida de imágenes
  Future<void> _syncSupabaseSession(String email, String password) async {
    try {
      AppLogger.debug(
        'Sincronizando sesión con Supabase...',
        name: 'AuthService',
      );
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user != null) {
        AppLogger.info(
          '✅ Sesión Supabase sincronizada: ${response.user!.id}',
          name: 'AuthService',
        );
      } else {
        AppLogger.warning(
          '⚠️ No se pudo sincronizar sesión con Supabase',
          name: 'AuthService',
        );
      }
    } catch (e) {
      AppLogger.error(
        '❌ Error al sincronizar con Supabase: $e',
        name: 'AuthService',
        error: e,
      );
      // No fallar el login si Supabase falla - el login del backend es el principal
    }
  }

  // Cerrar sesión
  Future<void> signOut() async {
    try {
      // Call backend logout endpoint (optional for JWT stateless)
      try {
        await _apiClient.post('/auth/logout', requireAuth: true);
      } catch (e) {
        // Ignore backend errors - JWT is stateless, client-side logout is sufficient
        AppLogger.error(
          'Backend logout call failed (non-critical): $e',
          name: 'AuthService',
          error: e,
        );
      }

      // Clear local token and user data
      await _apiClient.clearToken();
      _currentUser = null;
      _authStateController.add(AuthState(user: null));
    } catch (e) {
      // Even if everything fails, clear local data
      await _apiClient.clearToken();
      _currentUser = null;
      _authStateController.add(AuthState(user: null));
      throw ApiException(
        ApiErrorHandler.defaultMessage,
        technicalMessage: 'signOut: $e',
      );
    }
  }

  // Obtener el usuario actual
  User? get currentUser => _currentUser;

  // Verificar si hay un usuario autenticado
  bool get isAuthenticated => _currentUser != null;

  // Obtener el token actual
  Future<String?> getToken() async {
    return _apiClient.token;
  }

  // Escuchar cambios en el estado de autenticación
  Stream<AuthState> get authStateChanges => _authStateController.stream;

  // Recuperar contraseña (no implementado en el backend aún)
  Future<void> resetPassword(String email) async {
    // TODO: Implementar cuando el backend tenga este endpoint
    throw ApiException(
      'Esta función aún no está disponible.',
      technicalMessage: 'resetPassword: no implementado en el backend',
    );
  }

  // Dispose
  void dispose() {
    _authStateController.close();
  }
}
