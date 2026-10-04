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

  /// Retry de transporte únicamente para GET: tres intentos totales con
  /// backoff 300 ms y 600 ms. Las escrituras quedan excluidas porque repetir
  /// POST/PUT/PATCH/DELETE puede duplicar una operación no idempotente.
  static const int _maxGetAttempts = 3;
  static const List<Duration> _getRetryDelays = [
    Duration(milliseconds: 300),
    Duration(milliseconds: 600),
  ];

  /// Duración máxima de cada request HTTP antes de declarar timeout.
  /// Centralizado para que todos los verbos compartan el mismo umbral.
  Duration _requestTimeout = const Duration(seconds: 10);

  /// Transporte HTTP. En producción es un [http.Client] real; los tests lo
  /// reemplazan por un doble (`http.MockClient`, Fase 3 de docs/TESTING.md)
  /// vía [clientForTesting] — la suite corre sin red real.
  http.Client _client = http.Client();

  String? _token;

  /// Inyecta un doble HTTP (sin red). Restaurar en tearDown si es necesario.
  @visibleForTesting
  set clientForTesting(http.Client client) => _client = client;

  /// Fija el token directamente sin pasar por SecureStorage (tests).
  @visibleForTesting
  set tokenForTesting(String? token) => _token = token;

  /// Acorta el timeout en tests para no esperar los 10 s reales.
  @visibleForTesting
  set requestTimeoutForTesting(Duration value) => _requestTimeout = value;

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

  /// Ejecuta [request] aplicando timeout, retry de transporte para GET,
  /// normalización de respuestas 2xx y traducción centralizada de errores.
  ///
  /// [onSuccess] decodifica el body de la respuesta 2xx al tipo esperado
  /// (`Map<String, dynamic>` o `List<Map<String, dynamic>>`).
  Future<T> _execute<T>(
    Future<http.Response> Function() request,
    T Function(http.Response response) onSuccess, {
    bool retryOnUnauthorized = false,
    bool hasRetried = false,
    bool notifyUnauthorized = true,
    bool retryOnGet = false,
    int networkAttempt = 0,
    String? requestToken,
  }) async {
    // Parámetros del siguiente intento si hay que reintentar. La decisión se
    // toma DENTRO del try (y sus catch), pero la recursión se ejecuta FUERA
    // del try: así los errores del siguiente intento se propagan al caller y
    // no vuelven a caer en el manejo de errores de ESTE intento (evita dobles
    // reintentos). Un `return _execute(...)` dentro del try no dejaría que
    // los catch atraparan los errores asíncronos (lint
    // unawaited_return_in_try_block).
    _Reintento? reintento;

    try {
      final response = await request().timeout(_requestTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          return onSuccess(response);
        } on ApiException {
          rethrow;
        } catch (e) {
          throw ApiErrorHandler.dataException(e);
        }
      }

      if (response.statusCode == 401 && retryOnUnauthorized && !hasRetried) {
        // Si otro request ya actualizó el token mientras esta respuesta
        // estaba en vuelo, se reutiliza sin iniciar un segundo refresh
        // (single-flight).
        final tokenYaRenovado = requestToken != null && requestToken != _token;
        if (!tokenYaRenovado) {
          try {
            final newToken = await _refreshTokenOnce();
            if (newToken.isNotEmpty) {
              reintento = _Reintento(
                retryOnUnauthorized: false,
                hasRetried: true,
                networkAttempt: networkAttempt,
              );
            }
            // newToken vacío → sin reintento: cae al throw del 401 original.
          } catch (_) {
            await _handleRefreshFailure();
            throw _handleError(response, notifyUnauthorized: false);
          }
        } else {
          reintento = _Reintento(
            retryOnUnauthorized: false,
            hasRetried: true,
            networkAttempt: networkAttempt,
          );
        }
      } else if (retryOnGet &&
          response.statusCode >= 500 &&
          response.statusCode <= 599 &&
          networkAttempt < _maxGetAttempts - 1) {
        await Future<void>.delayed(_getRetryDelays[networkAttempt]);
        reintento = _Reintento(
          retryOnUnauthorized: retryOnUnauthorized,
          hasRetried: hasRetried,
          networkAttempt: networkAttempt + 1,
        );
      }

      if (reintento == null) {
        throw _handleError(response, notifyUnauthorized: notifyUnauthorized);
      }
    } on ApiException {
      // Ya traducida: se propaga sin doble envoltura.
      rethrow;
    } on TimeoutException {
      if (retryOnGet && networkAttempt < _maxGetAttempts - 1) {
        await Future<void>.delayed(_getRetryDelays[networkAttempt]);
        reintento = _Reintento(
          retryOnUnauthorized: retryOnUnauthorized,
          hasRetried: hasRetried,
          networkAttempt: networkAttempt + 1,
        );
      } else {
        throw ApiErrorHandler.timeoutException();
      }
    } catch (e) {
      final mappedError = ApiErrorHandler.fromException(e);
      if (retryOnGet &&
          mappedError.type == ApiErrorType.network &&
          networkAttempt < _maxGetAttempts - 1) {
        await Future<void>.delayed(_getRetryDelays[networkAttempt]);
        reintento = _Reintento(
          retryOnUnauthorized: retryOnUnauthorized,
          hasRetried: hasRetried,
          networkAttempt: networkAttempt + 1,
        );
      } else {
        throw mappedError;
      }
    }

    // Recursión FUERA del try: los errores del siguiente intento se propagan
    // al caller (cada intento traduce sus propios errores). El análisis de
    // flujo garantiza que reintento no es null aquí (todo path termina en
    // return, throw o reintento).
    return _execute(
      request,
      onSuccess,
      retryOnUnauthorized: reintento.retryOnUnauthorized,
      hasRetried: reintento.hasRetried,
      notifyUnauthorized: notifyUnauthorized,
      retryOnGet: retryOnGet,
      networkAttempt: reintento.networkAttempt,
      requestToken: requestToken,
    );
  }

  Future<String> _refreshTokenOnce() {
    final inFlightRefresh = _refreshCompleter;
    if (_isRefreshing && inFlightRefresh != null) {
      return inFlightRefresh.future.then((token) => token!);
    }

    // Estas asignaciones son síncronas y ocurren antes de cualquier await:
    // la primera llamada publica el Completer y las demás se encolan en él.
    final completer = Completer<String?>();
    _refreshCompleter = completer;
    _isRefreshing = true;
    unawaited(_runRefresh(completer));
    return completer.future.then((token) => token!);
  }

  Future<void> _runRefresh(Completer<String?> completer) async {
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
      () => _client.get(uri, headers: _getHeaders(requireAuth: requireAuth)),
      (response) {
        if (response.body.isEmpty) return {};
        return json.decode(response.body) as Map<String, dynamic>;
      },
      retryOnUnauthorized: _shouldRefresh(endpoint, requireAuth),
      notifyUnauthorized: endpoint != '/auth/refresh',
      retryOnGet: true,
      requestToken: _token,
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
      () => _client.get(uri, headers: _getHeaders(requireAuth: requireAuth)),
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
      retryOnGet: true,
      requestToken: _token,
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
      () => _client.post(
        uri,
        headers: _getHeaders(requireAuth: requireAuth),
        body: body != null ? json.encode(body) : null,
      ),
      (response) {
        if (response.body.isEmpty) return {};
        return json.decode(response.body) as Map<String, dynamic>;
      },
      // Un 401 puede reintentarse una vez tras renovar el token. Los retries
      // de transporte siguen deshabilitados porque podrían duplicar datos.
      retryOnUnauthorized: _shouldRefresh(endpoint, requireAuth),
      notifyUnauthorized: endpoint != '/auth/refresh',
      retryOnGet: false,
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
      () => _client.put(
        uri,
        headers: _getHeaders(requireAuth: requireAuth),
        body: body != null ? json.encode(body) : null,
      ),
      (response) {
        if (response.body.isEmpty) return {};
        return json.decode(response.body) as Map<String, dynamic>;
      },
      // Un 401 puede reintentarse una vez tras renovar el token. Los retries
      // de transporte siguen deshabilitados porque podrían duplicar datos.
      retryOnUnauthorized: _shouldRefresh(endpoint, requireAuth),
      notifyUnauthorized: endpoint != '/auth/refresh',
      retryOnGet: false,
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
      () => _client.patch(
        uri,
        headers: _getHeaders(requireAuth: requireAuth),
        body: body != null ? json.encode(body) : null,
      ),
      (response) {
        if (response.body.isEmpty) return {};
        return json.decode(response.body) as Map<String, dynamic>;
      },
      // Un 401 puede reintentarse una vez tras renovar el token. Los retries
      // de transporte siguen deshabilitados porque podrían duplicar datos.
      retryOnUnauthorized: _shouldRefresh(endpoint, requireAuth),
      notifyUnauthorized: endpoint != '/auth/refresh',
      retryOnGet: false,
    );
  }

  // DELETE request
  Future<void> delete(String endpoint, {bool requireAuth = true}) async {
    final uri = Uri.parse('$baseUrl$endpoint');

    await _execute(
      () => _client.delete(uri, headers: _getHeaders(requireAuth: requireAuth)),
      (_) => null,
      // Un 401 puede reintentarse una vez tras renovar el token. Los retries
      // de transporte siguen deshabilitados porque podrían duplicar datos.
      retryOnUnauthorized: _shouldRefresh(endpoint, requireAuth),
      notifyUnauthorized: endpoint != '/auth/refresh',
      retryOnGet: false,
    );
  }
}

/// Señal interna de reintento: el intento actual decidió encadenar otro
/// intento (401 con token renovado, o retry de transporte GET). La recursión
/// se ejecuta FUERA del try de [ApiClient._execute] para que los errores del
/// siguiente intento no vuelvan a caer en los catch del intento anterior.
class _Reintento {
  const _Reintento({
    required this.retryOnUnauthorized,
    required this.hasRetried,
    required this.networkAttempt,
  });

  final bool retryOnUnauthorized;
  final bool hasRetried;
  final int networkAttempt;
}
