import 'dart:async';
import 'dart:convert';
import 'api_client.dart';

// Clases compatibles con Supabase para mantener la misma interfaz
class User {
  final String id;
  final String email;
  final String? nombreCompleto;
  final String? rol;

  User({
    required this.id,
    required this.email,
    this.nombreCompleto,
    this.rol,
  });
}

class AuthResponse {
  final User user;
  final String? token;

  AuthResponse({
    required this.user,
    this.token,
  });
}

class AuthState {
  final User? user;

  AuthState({this.user});
}

class AuthService {
  final ApiClient _apiClient = ApiClient();
  User? _currentUser;
  final StreamController<AuthState> _authStateController = StreamController<AuthState>.broadcast();
  bool _isInitialized = false;

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
              utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))
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
          print('Error decoding token: $e');
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
  }) async {
    try {
      final response = await _apiClient.post(
        '/auth/register',
        body: {
          'email': email,
          'password': password,
          'nombreCompleto': nombreCompleto,
        },
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

      return AuthResponse(user: _currentUser!, token: token);
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
      final response = await _apiClient.post(
        '/auth/login',
        body: {
          'email': email,
          'password': password,
        },
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

      return AuthResponse(user: _currentUser!, token: token);
    } catch (e) {
      throw Exception('Error al iniciar sesión: $e');
    }
  }

  // Cerrar sesión
  Future<void> signOut() async {
    try {
      await _apiClient.clearToken();
      _currentUser = null;
      _authStateController.add(AuthState(user: null));
    } catch (e) {
      throw Exception('Error al cerrar sesión: $e');
    }
  }

  // Obtener el usuario actual
  User? get currentUser => _currentUser;

  // Verificar si hay un usuario autenticado
  bool get isAuthenticated => _currentUser != null;

  // Escuchar cambios en el estado de autenticación
  Stream<AuthState> get authStateChanges => _authStateController.stream;

  // Recuperar contraseña (no implementado en el backend aún)
  Future<void> resetPassword(String email) async {
    try {
      // TODO: Implementar cuando el backend tenga este endpoint
      throw Exception('Función no implementada en el backend');
    } catch (e) {
      throw Exception('Error al enviar correo de recuperación: $e');
    }
  }

  // Dispose
  void dispose() {
    _authStateController.close();
  }
}
