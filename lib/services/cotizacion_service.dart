import 'dart:convert';
import 'package:http/http.dart' as http;
import 'secure_storage_service.dart';
import '../models/cotizacion.dart';
import '../config/app_config.dart';

class BadRequestException implements Exception {
  final String message;
  BadRequestException(this.message);

  @override
  String toString() => 'BadRequestException: $message';
}

class ForbiddenException implements Exception {
  final String message;
  ForbiddenException(this.message);

  @override
  String toString() => 'ForbiddenException: $message';
}

class NotFoundException implements Exception {
  final String message;
  NotFoundException(this.message);

  @override
  String toString() => 'NotFoundException: $message';
}

class ServerException implements Exception {
  final String message;
  ServerException(this.message);

  @override
  String toString() => 'ServerException: $message';
}

class CotizacionService {
  static final String baseUrl = AppConfig.baseUrl;

  Future<String> _getToken() async {
    // Usa SecureStorageService para obtener el token cifrado
    final token = await SecureStorageService().readToken();
    if (token == null || token.isEmpty) {
      throw Exception('No hay token de autenticación');
    }
    return token;
  }

  Future<List<Cotizacion>> obtenerCotizacionesPorSolicitud(
    String solicitudId,
  ) async {
    try {
      final token = await _getToken();
      if (token.isEmpty) {
        throw Exception('No hay token de autenticación');
      }

      final uri = Uri.parse('$baseUrl/quotations/request/$solicitudId');

      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('La conexión está lenta. Intenta nuevamente.');
            },
          );

      switch (response.statusCode) {
        case 200:
          if (response.body.isEmpty) {
            return [];
          }
          final List<dynamic> jsonData =
              json.decode(response.body) as List<dynamic>;
          return jsonData
              .map((json) => Cotizacion.fromJson(json as Map<String, dynamic>))
              .toList();
        case 400:
          final body = json.decode(response.body) as Map<String, dynamic>;
          throw BadRequestException(
            body['error'] as String? ?? 'Solicitud inválida',
          );
        case 403:
          final body = json.decode(response.body) as Map<String, dynamic>;
          throw ForbiddenException(
            body['error'] as String? ?? 'No tienes permiso',
          );
        case 404:
          final body = json.decode(response.body) as Map<String, dynamic>;
          throw NotFoundException(
            body['error'] as String? ?? 'Recurso no encontrado',
          );
        default:
          throw ServerException('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      if (e is BadRequestException ||
          e is ForbiddenException ||
          e is NotFoundException ||
          e is ServerException) {
        rethrow;
      }
      throw Exception('Error al obtener cotizaciones: $e');
    }
  }

  Future<Map<String, dynamic>> aceptarCotizacion(String cotizacionId) async {
    try {
      final token = await _getToken();
      if (token.isEmpty) {
        throw Exception('No hay token de autenticación');
      }

      final uri = Uri.parse('$baseUrl/quotations/$cotizacionId/accept');

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('La conexión está lenta. Intenta nuevamente.');
            },
          );

      switch (response.statusCode) {
        case 200:
          if (response.body.isEmpty) {
            return {};
          }
          return json.decode(response.body) as Map<String, dynamic>;
        case 400:
          final body = json.decode(response.body) as Map<String, dynamic>;
          throw BadRequestException(
            body['error'] as String? ?? 'Solicitud inválida',
          );
        case 403:
          final body = json.decode(response.body) as Map<String, dynamic>;
          throw ForbiddenException(
            body['error'] as String? ?? 'No tienes permiso',
          );
        case 404:
          final body = json.decode(response.body) as Map<String, dynamic>;
          throw NotFoundException(
            body['error'] as String? ?? 'Recurso no encontrado',
          );
        default:
          throw ServerException('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      if (e is BadRequestException ||
          e is ForbiddenException ||
          e is NotFoundException ||
          e is ServerException) {
        rethrow;
      }
      throw Exception('Error al aceptar cotización: $e');
    }
  }

  Future<Map<String, dynamic>> rechazarCotizacion(String cotizacionId) async {
    try {
      final token = await _getToken();
      if (token.isEmpty) {
        throw Exception('No hay token de autenticación');
      }

      final uri = Uri.parse('$baseUrl/quotations/$cotizacionId/reject');

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('La conexión está lenta. Intenta nuevamente.');
            },
          );

      switch (response.statusCode) {
        case 200:
          if (response.body.isEmpty) {
            return {};
          }
          return json.decode(response.body) as Map<String, dynamic>;
        case 400:
          final body = json.decode(response.body) as Map<String, dynamic>;
          throw BadRequestException(
            body['error'] as String? ?? 'Solicitud inválida',
          );
        case 403:
          final body = json.decode(response.body) as Map<String, dynamic>;
          throw ForbiddenException(
            body['error'] as String? ?? 'No tienes permiso',
          );
        case 404:
          final body = json.decode(response.body) as Map<String, dynamic>;
          throw NotFoundException(
            body['error'] as String? ?? 'Recurso no encontrado',
          );
        default:
          throw ServerException('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      if (e is BadRequestException ||
          e is ForbiddenException ||
          e is NotFoundException ||
          e is ServerException) {
        rethrow;
      }
      throw Exception('Error al rechazar cotización: $e');
    }
  }
}
