import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/orden_compra.dart';
import 'api_client.dart';

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

class OrdenCompraService {
  static const String baseUrl = 'http://192.168.100.2:3000/api';
  final ApiClient _apiClient = ApiClient();

  Future<String> _getToken() async {
    // Usa el ApiClient singleton que ya maneja los tokens desde SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    if (token.isEmpty) {
      throw Exception('No hay token de autenticación');
    }
    return token;
  }

  Future<OrdenCompra> getOrdenDetalle(String ordenId) async {
    try {
      final token = await _getToken();
      if (token.isEmpty) {
        throw Exception('No hay token de autenticación');
      }

      final uri = Uri.parse('$baseUrl/orders/$ordenId');

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
            throw Exception('Respuesta vacía del servidor');
          }
          final jsonData = json.decode(response.body) as Map<String, dynamic>;
          final data = jsonData['data'] as Map<String, dynamic>?;
          if (data != null) {
            return OrdenCompra.fromJson(data);
          }
          return OrdenCompra.fromJson(jsonData);
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
      throw Exception('Error al obtener el detalle de la orden: $e');
    }
  }
}
