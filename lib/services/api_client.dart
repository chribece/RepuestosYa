import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_error_handler.dart';
import '../utils/app_logger.dart';

class ApiClient {
  static const String baseUrl = 'http://192.168.100.2:3000/api';
  static const String _tokenKey = 'auth_token';

  /// Duración máxima de cada request HTTP antes de declarar timeout.
  /// Centralizado para que todos los verbos compartan el mismo umbral.
  static const Duration _requestTimeout = Duration(seconds: 10);

  String? _token;

  // Constructor privado para singleton
  ApiClient._privateConstructor();

  static final ApiClient _instance = ApiClient._privateConstructor();

  factory ApiClient() => _instance;

  // Inicializar el cliente cargando el token desde SharedPreferences
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    AppLogger.debug(
      'init: token = ${_token != null ? "EXISTS" : "NULL"}',
      name: 'ApiClient',
    );
  }

  // Guardar el token
  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    AppLogger.debug('setToken: token saved successfully', name: 'ApiClient');
  }

  // Obtener el token actual
  String? get token => _token;

  // Verificar si hay un token guardado
  bool get isAuthenticated => _token != null;

  // Limpiar el token (logout)
  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // Obtener los headers comunes
  Map<String, String> _getHeaders({bool requireAuth = true}) {
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (requireAuth && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }

    return headers;
  }

  /// Traduce una respuesta HTTP fallida a una [ApiException] con mensaje
  /// amigable. Conserva el log técnico a través de [ApiErrorHandler] y
  /// preserva el `statusCode` en la excepción para que la lógica de negocio
  /// (p. ej. distinguir un 404 de "perfil no existe" de un 404 de "recurso
  /// no encontrado") pueda seguir tomándolo mediante `e.statusCode`.
  ApiException _handleError(http.Response response) =>
      ApiErrorHandler.fromResponse(response);

  /// Ejecuta [request] aplicando timeout, normalización de respuestas 2xx y
  /// traducción centralizada de errores HTTP / de red a [ApiException].
  ///
  /// [onSuccess] decodifica el body de la respuesta 2xx al tipo esperado
  /// (`Map<String, dynamic>` o `List<Map<String, dynamic>>`).
  Future<T> _execute<T>(
    Future<http.Response> Function() request,
    T Function(http.Response response) onSuccess,
  ) async {
    try {
      final response = await request().timeout(_requestTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return onSuccess(response);
      }
      throw _handleError(response);
    } on ApiException {
      // Ya traducida: se propaga sin doble envoltura.
      rethrow;
    } on TimeoutException {
      throw ApiErrorHandler.timeoutException();
    } catch (e) {
      // SocketException, ClientException, errores de parseo, etc.
      throw ApiErrorHandler.fromException(e);
    }
  }

  // GET request
  Future<Map<String, dynamic>> get(
    String endpoint, {
    bool requireAuth = true,
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse(
      '$baseUrl$endpoint',
    ).replace(queryParameters: queryParams);

    return _execute(
      () => http.get(uri, headers: _getHeaders(requireAuth: requireAuth)),
      (response) {
        if (response.body.isEmpty) return {};
        return json.decode(response.body) as Map<String, dynamic>;
      },
    );
  }

  // GET request para listas
  Future<List<Map<String, dynamic>>> getList(
    String endpoint, {
    bool requireAuth = true,
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse(
      '$baseUrl$endpoint',
    ).replace(queryParameters: queryParams);

    return _execute(
      () => http.get(uri, headers: _getHeaders(requireAuth: requireAuth)),
      (response) {
        if (response.body.isEmpty) return [];
        final data = json.decode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
        return [data as Map<String, dynamic>];
      },
    );
  }

  // POST request
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');

    return _execute(
      () => http.post(
        uri,
        headers: _getHeaders(requireAuth: requireAuth),
        body: body != null ? json.encode(body) : null,
      ),
      (response) {
        if (response.body.isEmpty) return {};
        return json.decode(response.body) as Map<String, dynamic>;
      },
    );
  }

  // PUT request
  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');

    return _execute(
      () => http.put(
        uri,
        headers: _getHeaders(requireAuth: requireAuth),
        body: body != null ? json.encode(body) : null,
      ),
      (response) {
        if (response.body.isEmpty) return {};
        return json.decode(response.body) as Map<String, dynamic>;
      },
    );
  }

  // DELETE request
  Future<void> delete(String endpoint, {bool requireAuth = true}) async {
    final uri = Uri.parse('$baseUrl$endpoint');

    await _execute(
      () => http.delete(uri, headers: _getHeaders(requireAuth: requireAuth)),
      (_) => null,
    );
  }
}
