import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'app_logger.dart';

/// Contexto de uso en el que se captura un error. Permite al mapper devolver
/// un mensaje amigable adaptado a la pantalla, ya que un mismo código HTTP
/// puede significar cosas distintas según el flujo (p. ej. un 401 en Login
/// significa credenciales inválidas, mientras que un 401 en una pantalla ya
/// autenticada significa sesión expirada).
enum ApiErrorContext {
  /// Flujo de inicio de sesión / registro: un 401 son credenciales inválidas,
  /// no una sesión expirada.
  auth,

  /// Cualquier pantalla que ya asume sesión activa: un 401 significa token
  /// caduco o inválido.
  session,
}

/// Excepción única que transporta tanto el mensaje amigable para el usuario
/// como los detalles técnicos preservados para depuración.
///
/// El [toString()] devuelve **solo** el [message] amigable para que cualquier
/// `SnackBar` o `RyStateContainer` que haga `$e` muestre texto comprensible y
/// nunca exponga detalles crudos del backend.
class ApiException implements Exception {
  /// Código HTTP de la respuesta que originó el error, o `null` cuando el
  /// fallo ocurrió antes de recibir una respuesta (timeout, sin conexión).
  final int? statusCode;

  /// Mensaje amigable en español, listo para mostrar al usuario final.
  final String message;

  /// Mensaje técnico original del backend (campo `error`/`message` del body)
  /// o descripción de la excepción de red. Solo se persiste en el logger; no
  /// se muestra en la UI.
  final String? technicalMessage;

  const ApiException(this.message, {this.statusCode, this.technicalMessage});

  @override
  String toString() => message;
}

/// Traductor centralizado de errores HTTP / de red a mensajes comprensibles
/// para el usuario.
///
/// El [ApiClient] construye todas sus excepciones a través de esta clase, de
/// modo que ninguna pantalla recibe un código HTTP crudo o un `SocketException`
/// sin traducir. Los mensajes están alineados con la tabla
/// "Traducción de códigos de estado API" de `docs/DESIGN_SYSTEM.md`.
class ApiErrorHandler {
  const ApiErrorHandler._();

  /// Mensajes amigables por código HTTP. Cubre los casos mínimos requeridos
  /// por la auditoría (400/401/403/404/409/422/500). Cualquier código fuera
  /// del mapa cae en [defaultMessage].
  static const Map<int, String> _statusMessages = {
    400: 'Revisa los datos ingresados e intenta nuevamente.',
    401: 'Tu sesión expiró. Inicia sesión nuevamente.',
    403: 'No tienes permisos para realizar esta acción.',
    404: 'No encontramos la información solicitada.',
    409: 'Ya existe un registro con esos datos.',
    422: 'Algunos datos no cumplen con el formato requerido.',
    500: 'Ocurrió un problema en el servidor. Intenta más tarde.',
  };

  static const String timeoutMessage =
      'La conexión está tardando demasiado. Revisa tu internet e intenta nuevamente.';
  static const String noConnectionMessage =
      'No pudimos conectarnos. Revisa tu conexión a internet.';
  static const String defaultMessage =
      'No pudimos completar la operación. Intenta nuevamente.';

  /// Mensaje específico para credenciales inválidas en el flujo de Login.
  /// El backend responde 401 con `{ error: 'Credenciales inválidas' }` y
  /// **no distingue** correo inexistente de contraseña incorrecta (Supabase
  /// Auth devuelve el mismo error para ambos casos), por lo que el mensaje
  /// cubre ambas causas sin revelar cuál falló (evita user enumeration).
  static const String invalidCredentialsMessage =
      'Correo o contraseña incorrectos.';

  /// Construye una [ApiException] a partir de una respuesta HTTP,
  /// preservando el [statusCode] y el mensaje técnico del body para el log.
  static ApiException fromResponse(http.Response response) {
    final code = response.statusCode;
    final friendly = _statusMessages[code] ?? defaultMessage;

    // Para 422, preservamos el body completo para mapear errores a campos.
    final technical = code == 422
        ? response.body
        : _extractTechnical(response.body, code);

    AppLogger.warning(
      'API $code · técnico: ${technical ?? '<empty>'} · body: ${response.body}',
      name: 'ApiErrorHandler',
    );

    return ApiException(
      friendly,
      statusCode: code,
      technicalMessage: technical,
    );
  }

  /// Intenta extraer el mensaje técnico del body de la respuesta para
  /// depuración. Devuelve `null` si el body no es JSON o no contiene un
  /// campo `error`/`message` legible.
  static String? _extractTechnical(String body, int code) {
    if (body.isEmpty) return null;
    try {
      final decoded = json.decode(body);
      if (decoded is Map) {
        final err = decoded['error'] ?? decoded['message'];
        if (err is String && err.isNotEmpty) return err;
      }
    } catch (_) {
      // Body no es JSON válido; conservamos reason phrase como técnico.
      return 'HTTP $code';
    }
    return null;
  }

  /// Devuelve una [ApiException] para timeout. Reutilizada por [ApiClient]
  /// en el callback `onTimeout` de cada request.
  static ApiException timeoutException() =>
      const ApiException(timeoutMessage, technicalMessage: 'Request timeout');

  /// Construye una [ApiException] a partir de una excepción de red o de
  /// cualquier error no HTTP (SocketException, ClientException, etc.).
  /// Si [error] ya es una [ApiException] se devuelve tal cual para no perder
  /// el statusCode original.
  static ApiException fromException(Object error) {
    if (error is ApiException) return error;
    if (error is TimeoutException) return timeoutException();
    if (error is SocketException ||
        error is HttpException ||
        _looksLikeNetworkError(error.toString())) {
      return ApiException(
        noConnectionMessage,
        technicalMessage: error.toString(),
      );
    }
    return ApiException(defaultMessage, technicalMessage: error.toString());
  }

  /// Heurística ligera para detectar errores de red envueltos por `package:http`
  /// (`ClientException`) o por `dart:io`, ya que no todas las excepciones de
  /// red heredan de `SocketException` (p. ej. `http.ClientException`).
  static bool _looksLikeNetworkError(String text) {
    final lower = text.toLowerCase();
    return lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection timed out') ||
        lower.contains('software caused connection abort');
  }

  /// Devuelve un mensaje listo para mostrar al usuario a partir de cualquier
  /// excepción capturada en una pantalla.
  ///
  /// - Si es una [ApiException], devuelve directamente su [ApiException.message]
  ///   (texto amigable, sin prefijos).
  /// - En caso contrario, elimina los prefijos `Exception: ` que los servicios
  ///   añaden al envolver (`throw Exception('Error al X: $e')`) y devuelve el
  ///   texto resultante. Si tras limpiar queda un texto técnico o vacío, cae
  ///   en [defaultMessage].
  ///
  /// El [context] opcional adapta el mensaje al flujo donde se captura el
  /// error (ver [ApiErrorContext]).
  static String userMessage(Object error, {ApiErrorContext? context}) {
    if (context == ApiErrorContext.auth) {
      return _authMessage(error);
    }
    if (context == ApiErrorContext.session) {
      final apiError = _asApiException(error);
      if (apiError?.statusCode == 401) {
        return _statusMessages[401]!;
      }
      if (apiError?.statusCode == 403) {
        return _statusMessages[403]!;
      }
    }
    return _userMessageDefault(error);
  }

  /// Extrae errores de validación del backend (422) y los mapea a un [Map]
  /// de campo -> mensaje.
  ///
  /// Soporta formatos:
  /// - { "errors": [{ "field": "email", "message": "..." }] } (Normalizado)
  /// - { "errores": [{ "campo": "email", "mensaje": "..." }] } (Legacy)
  static Map<String, String> mapValidationErrors(Object error) {
    if (error is! ApiException || error.statusCode != 422) return {};

    try {
      final technical = error.technicalMessage;
      if (technical == null) return {};

      final decoded = json.decode(technical);
      if (decoded is! Map) return {};

      final errorsList = decoded['errors'] ?? decoded['errores'];
      if (errorsList is List) {
        final Map<String, String> result = {};
        for (var err in errorsList) {
          if (err is Map) {
            // Soporte para campo/field y mensaje/message
            final field = err['field'] ?? err['campo'];
            final message = err['message'] ?? err['mensaje'];

            if (field != null && message != null) {
              result[field.toString()] = message.toString();
            }
          }
        }
        return result;
      }
    } catch (e) {
      AppLogger.error(
        'Error al parsear errores 422',
        name: 'ApiErrorHandler',
        error: e,
      );
    }

    return {};
  }

  /// Implementación base de [userMessage] sin contexto.
  static String _userMessageDefault(Object error) {
    if (error is ApiException) return error.message;
    var text = error.toString();
    while (text.startsWith('Exception: ')) {
      text = text.substring('Exception: '.length);
    }
    if (text.isEmpty ||
        text == 'null' ||
        text.contains('StackTrace') ||
        text.contains('BadRequestException: ') ||
        text.contains('ForbiddenException: ') ||
        text.contains('NotFoundException: ') ||
        text.contains('ServerException: ') ||
        text.contains('SocketException: ') ||
        text.contains('ClientException: ') ||
        text.contains('TimeoutException: ')) {
      return defaultMessage;
    }
    return text;
  }

  /// Mensaje para el flujo de Login/Registro.
  static String _authMessage(Object error) {
    final apiError = _asApiException(error);
    if (apiError != null) {
      final code = apiError.statusCode;
      // Credenciales inválidas (401) o perfil no encontrado (404) tras auth
      // en Supabase: desde el punto de vista del usuario el login falló por
      // credenciales. No revelamos si el email existe o no.
      if (code == 400 || code == 401 || code == 404) {
        return invalidCredentialsMessage;
      }
      // Timeout, sin conexión, 500, 403, 409, 422: conservan su mensaje
      // amigable original.
      return apiError.message;
    }
    // Excepción de red pura (timeout / sin conexión): la traduce fromException
    // si no era ya ApiException, así que delegamos en userMessage genérico.
    return userMessage(error);
  }

  /// Devuelve la excepción como [ApiException] si ya lo es, o la traduce vía
  /// [fromException] para inspeccionar el `statusCode`. No la propaga, solo la
  /// usa para decidir el mensaje.
  static ApiException? _asApiException(Object error) {
    if (error is ApiException) return error;
    // Solo traducimos si parece un error de red/HTTP; si es otra excepción
    // arbitraria devolvemos null para que el flujo caiga en userMessage.
    if (error is TimeoutException ||
        error is SocketException ||
        error is HttpException ||
        _looksLikeNetworkError(error.toString())) {
      return fromException(error);
    }
    return null;
  }
}
