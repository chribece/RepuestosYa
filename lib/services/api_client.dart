import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String baseUrl = 'http://192.168.10.232:3000/api';
  static const String _tokenKey = 'auth_token';
  
  String? _token;
  
  // Constructor privado para singleton
  ApiClient._privateConstructor();
  
  static final ApiClient _instance = ApiClient._privateConstructor();
  
  factory ApiClient() => _instance;
  
  // Inicializar el cliente cargando el token desde SharedPreferences
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    print('ApiClient init: token = ${_token != null ? "EXISTS" : "NULL"}');
  }
  
  // Guardar el token
  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    print('ApiClient setToken: token saved successfully');
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
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    
    if (requireAuth && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    
    return headers;
  }
  
  // Manejo de errores
  Exception _handleError(http.Response response) {
    String message = 'Error desconocido';
    
    try {
      final body = json.decode(response.body);
      if (body is Map && body.containsKey('error')) {
        message = body['error'] as String;
      } else if (body is Map && body.containsKey('message')) {
        message = body['message'] as String;
      }
    } catch (e) {
      message = 'Error ${response.statusCode}: ${response.reasonPhrase}';
    }
    
    return Exception(message);
  }
  
  // GET request
  Future<Map<String, dynamic>> get(
    String endpoint, {
    bool requireAuth = true,
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint').replace(
      queryParameters: queryParams,
    );
    
    final response = await http.get(
      uri,
      headers: _getHeaders(requireAuth: requireAuth),
    );
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return {};
      }
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw _handleError(response);
    }
  }
  
  // GET request para listas
  Future<List<Map<String, dynamic>>> getList(
    String endpoint, {
    bool requireAuth = true,
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint').replace(
      queryParameters: queryParams,
    );
    
    final response = await http.get(
      uri,
      headers: _getHeaders(requireAuth: requireAuth),
    );
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return [];
      }
      final data = json.decode(response.body);
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
      return [data as Map<String, dynamic>];
    } else {
      throw _handleError(response);
    }
  }
  
  // POST request
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    
    final response = await http.post(
      uri,
      headers: _getHeaders(requireAuth: requireAuth),
      body: body != null ? json.encode(body) : null,
    );
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return {};
      }
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw _handleError(response);
    }
  }
  
  // PUT request
  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    
    final response = await http.put(
      uri,
      headers: _getHeaders(requireAuth: requireAuth),
      body: body != null ? json.encode(body) : null,
    );
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return {};
      }
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw _handleError(response);
    }
  }
  
  // DELETE request
  Future<void> delete(
    String endpoint, {
    bool requireAuth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    
    final response = await http.delete(
      uri,
      headers: _getHeaders(requireAuth: requireAuth),
    );
    
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _handleError(response);
    }
  }
}
