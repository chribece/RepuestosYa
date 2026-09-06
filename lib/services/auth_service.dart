import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../utils/api_error_handler.dart';
import '../utils/app_logger.dart';
import 'api_client.dart';
import 'secure_storage_service.dart';

// Clases compatibles con Supabase para mantener la misma interfaz
class User {
  final String id;
  final String email;
  final String? nombreCompleto;
  final String? rol;

  User({required this.id, required this.email, this.nombreCompleto, this.rol});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      nombreCompleto: json['nombre_completo'] as String?,
      rol: json['rol'] as String?,
    );
  }
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
  final SecureStorageService _secureStorage = SecureStorageService();
  User? _currentUser;
  final StreamController<AuthState> _authStateController =
      StreamController<AuthState>.broadcast();

  // Callback opcional para limpiar datos locales (inyectado desde fuera)
  Future<void> Function()? onLogoutCleanup;

  // Constructor privado para singleton
  AuthService._privateConstructor() {
    // La inicialización se llama explícitamente desde main.dart o vía getter si es necesario
    _apiClient.onUnauthorized = clearLocalSession;
  }

  static final AuthService _instance = AuthService._privateConstructor();
  factory AuthService() => _instance;

  // Inicializar autenticación cargando token
  Future<void> init() async {
    await _apiClient.init();
    final token = await _secureStorage.readToken();

    if (token != null) {
      try {
        // Al arrancar, si existe token, llama GET /api/auth/me
        final response = await _apiClient.get('/auth/me');
        if (response['success'] == true) {
          final userData = response['data'] as Map<String, dynamic>;
          _currentUser = User.fromJson(userData);
          _authStateController.add(AuthState(user: _currentUser));
          AppLogger.info(
            'Sesión restaurada correctamente',
            name: 'AuthService',
          );
        }
      } on ApiException catch (e) {
        // SOLO limpiar sesión si es un error de autenticación (401 o 403)
        if (e.statusCode == 401 || e.statusCode == 403) {
          AppLogger.warning(
            'Sesión inválida, limpiando datos locales',
            name: 'AuthService',
          );
          await clearLocalSession();
        } else {
          // Es un error de red u otro, mantenemos la sesión local (offline-first)
          AppLogger.info(
            'Error de red al validar sesión, trabajando en modo offline',
            name: 'AuthService',
          );
        }
      } catch (e) {
        AppLogger.error(
          'Error inesperado en init auth: $e',
          name: 'AuthService',
        );
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
          'rol': rol,
        },
        requireAuth: false,
      );

      AppLogger.info('Registro exitoso', name: 'AuthService');
      final token = response['token'] as String;
      final refreshToken = response['refreshToken'] as String?;

      final userData = response['user'] as Map<String, dynamic>;
      _currentUser = User.fromJson(userData);

      // Persistir token y datos de usuario en almacenamiento cifrado
      await _apiClient.setToken(token);
      await _secureStorage.saveToken(token, refreshToken: refreshToken);
      await _secureStorage.saveUser(_currentUser!.id, _currentUser!.rol ?? '');

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
      final refreshToken = response['refreshToken'] as String?;

      final userData = response['user'] as Map<String, dynamic>;
      _currentUser = User.fromJson(userData);

      // Persistir token y datos de usuario en almacenamiento cifrado
      await _apiClient.setToken(token);
      await _secureStorage.saveToken(token, refreshToken: refreshToken);
      await _secureStorage.saveUser(_currentUser!.id, _currentUser!.rol ?? '');

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
      final response = await supabase.Supabase.instance.client.auth
          .signInWithPassword(email: email, password: password);
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

  // Limpiar sesión local (usado por ApiClient ante 401)
  Future<void> clearLocalSession() async {
    _currentUser = null;
    await _apiClient.clearToken();
    await _secureStorage.clearAll();

    // También limpiar DB local ante cierre forzado si el callback está registrado
    if (onLogoutCleanup != null) {
      await onLogoutCleanup!();
    }

    _authStateController.add(AuthState(user: null));
    AppLogger.info('Sesión local limpiada', name: 'AuthService');
  }

  // Cerrar sesión
  Future<void> signOut() async {
    try {
      AppLogger.info('Iniciando cierre de sesión...', name: 'AuthService');

      // 1. Intentar avisar al servidor (opcional)
      try {
        await _apiClient.post('/auth/logout', requireAuth: true);
      } catch (e) {
        // Ignoramos 401 u otros errores de red durante el logout
      }

      // 2. Limpiar memoria y almacenamiento seguro INMEDIATAMENTE
      _currentUser = null;
      await _secureStorage.clearAll();
      await _apiClient.clearToken();

      // 3. Limpiar base de datos local (con seguridad ante fallos)
      if (onLogoutCleanup != null) {
        try {
          await onLogoutCleanup!();
        } catch (e) {
          AppLogger.error(
            'Fallo limpieza DB local en logout',
            name: 'AuthService',
            error: e,
          );
        }
      }

      // 4. Notificar cambio de estado para disparar navegación al Login
      _authStateController.add(AuthState(user: null));
      AppLogger.info('Cierre de sesión finalizado', name: 'AuthService');
    } catch (e) {
      AppLogger.error(
        'Error inesperado en signOut',
        name: 'AuthService',
        error: e,
      );
      // Pase lo que pase, forzamos el estado nulo para que el usuario pueda volver a loguearse
      _currentUser = null;
      _authStateController.add(AuthState(user: null));
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
