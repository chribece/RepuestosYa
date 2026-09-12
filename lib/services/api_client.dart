import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'secure_storage_service.dart';
import '../theme/app_colors.dart';
import '../utils/api_error_handler.dart';
import '../utils/app_logger.dart';
import '../utils/keys.dart';
import '../config/app_config.dart';

class ApiClient {
  static final String baseUrl = AppConfig.baseUrl;

  /// Duración máxima de cada request HTTP antes de declarar timeout.
  /// Centralizado para que todos los verbos compartan el mismo umbral.
  static const Duration _requestTimeout = Duration(seconds: 10);

  String? _token;

  // Constructor privado para singleton
  ApiClient._privateConstructor();

  static final ApiClient _instance = ApiClient._privateConstructor();

  factory ApiClient() => _instance;

  /// Callback para notificar errores 401 sin crear dependencias circulares.
  VoidCallback? onUnauthorized;

  /// Callback que renueva el JWT usando el refresh token persistido.
  Future<String?> Function()? onRefreshToken;

  /// Callback asíncrono para limpiar completamente la sesión tras un refresh fallido.
  Future<void> Function()? onUnauthorizedAsync;

  bool _isRefreshing = false;
  Completer<String?>? _refreshCompleter;

  final SecureStorageService _secureStorage = SecureStorageService();

  // Inicializar el cliente cargando el token desde SecureStorage
  Future<void> init() async {
    _token = await _secureStorage.readToken();
    AppLogger.debug(
      'init: token = ${_token != null ? "EXISTS" : "NULL"}',
      name: 'ApiClient',
    );
  }

  // Guardar el token
  Future<void> setToken(String token) async {
    _token = token;
    await _secureStorage.saveToken(token);
    AppLogger.debug('setToken: token saved successfully', name: 'ApiClient');
  }

  // Obtener el token actual
  String? get token => _token;

  // Verificar si hay un token guardado
  bool get isAuthenticated => _token != null;

  // Limpiar el token (logout)
  Future<void> clearToken() async {
    _token = null;
    await _secureStorage.clearAll();
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
  ApiException _handleError(
    http.Response response, {
    bool notifyUnauthorized = true,
  }) {
    final apiException = ApiErrorHandler.fromResponse(response);

    if (apiException.statusCode == 401 && notifyUnauthorized) {
      // Centralización 401: Sesión expirada o token inválido.
      if (onUnauthorizedAsync != null) {
        unawaited(onUnauthorizedAsync!());
      } else if (onUnauthorized != null) {
        onUnauthorized!();
      } else {
        unawaited(clearToken());
      }
      AppLogger.warning('Sesión expirada (401).', name: 'ApiClient');
    } else if (apiException.statusCode == 403) {
      // Centralización 403: Prohibido.
      // Mostramos mensaje sin cerrar sesión.
      _showForbiddenMessage(apiException.message);
      AppLogger.warning('Acceso prohibido (403).', name: 'ApiClient');
    }

    return apiException;
  }

  void _showForbiddenMessage(String message) {
    // Usamos el RyKeys.rootNavigatorKey para acceder al contexto global y mostrar SnackBar
    final context = RyKeys.rootNavigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Ejecuta [request] aplicando timeout, normalización de respuestas 2xx y
  /// traducción centralizada de errores HTTP / de red a [ApiException].
  ///
  /// [onSuccess] decodifica el body de la respuesta 2xx al tipo esperado
  /// (`Map<String, dynamic>` o `List<Map<String, dynamic>>`).
  Future<T> _execute<T>(
    Future<http.Response> Function() request,
    T Function(http.Response response) onSuccess, {
    bool retryOnUnauthorized = false,
    bool hasRetried = false,
    bool notifyUnauthorized = true,
  }) async {
    try {
      final response = await request().timeout(_requestTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return onSuccess(response);
      }

      if (response.statusCode == 401 && retryOnUnauthorized && !hasRetried) {
        try {
          final newToken = await _refreshTokenOnce();
          if (newToken.isNotEmpty) {
            return _execute(
              request,
              onSuccess,
              retryOnUnauthorized: false,
              hasRetried: true,
              notifyUnauthorized: notifyUnauthorized,
            );
          }
        } catch (_) {
          await _handleRefreshFailure();
          throw _handleError(response, notifyUnauthorized: false);
        }
      }

      throw _handleError(response, notifyUnauthorized: notifyUnauthorized);
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

  Future<String> _refreshTokenOnce() async {
    if (_isRefreshing && _refreshCompleter != null) {
      return (await _refreshCompleter!.future)!;
    }

    final completer = Completer<String?>();
    _isRefreshing = true;
    _refreshCompleter = completer;

    try {
      final refreshedToken = await onRefreshToken?.call();
      if (refreshedToken == null || refreshedToken.isEmpty) {
        throw const ApiException(
          'No se pudo renovar la sesión.',
          statusCode: 401,
        );
      }
      completer.complete(refreshedToken);
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }

    return (await completer.future)!;
  }

  Future<void> _handleRefreshFailure() async {
    try {
      if (onUnauthorizedAsync != null) {
        await onUnauthorizedAsync!();
      } else {
        await clearToken();
        onUnauthorized?.call();
      }
    } catch (_) {
      await clearToken();
    }
  }

  bool _shouldRefresh(String endpoint, bool requireAuth) {
    return requireAuth &&
        endpoint != '/auth/login' &&
        endpoint != '/auth/refresh';
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
      retryOnUnauthorized: _shouldRefresh(endpoint, requireAuth),
      notifyUnauthorized: endpoint != '/auth/refresh',
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
      retryOnUnauthorized: _shouldRefresh(endpoint, requireAuth),
      notifyUnauthorized: endpoint != '/auth/refresh',
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
      retryOnUnauthorized: _shouldRefresh(endpoint, requireAuth),
      notifyUnauthorized: endpoint != '/auth/refresh',
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
      retryOnUnauthorized: _shouldRefresh(endpoint, requireAuth),
      notifyUnauthorized: endpoint != '/auth/refresh',
    );
  }

  // PATCH request
  Future<Map<String, dynamic>> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');

    return _execute(
      () => http.patch(
        uri,
        headers: _getHeaders(requireAuth: requireAuth),
        body: body != null ? json.encode(body) : null,
      ),
      (response) {
        if (response.body.isEmpty) return {};
        return json.decode(response.body) as Map<String, dynamic>;
      },
      retryOnUnauthorized: _shouldRefresh(endpoint, requireAuth),
      notifyUnauthorized: endpoint != '/auth/refresh',
    );
  }

  // DELETE request
  Future<void> delete(String endpoint, {bool requireAuth = true}) async {
    final uri = Uri.parse('$baseUrl$endpoint');

    await _execute(
      () => http.delete(uri, headers: _getHeaders(requireAuth: requireAuth)),
      (_) => null,
      retryOnUnauthorized: _shouldRefresh(endpoint, requireAuth),
      notifyUnauthorized: endpoint != '/auth/refresh',
    );
  }
}
