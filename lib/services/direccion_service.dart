import 'api_client.dart';

class DireccionService {
  final ApiClient _apiClient = ApiClient();

  // Obtener todas las direcciones del usuario
  Future<List<Map<String, dynamic>>> getDirecciones() async {
    try {
      final response = await _apiClient.getList('/addresses');
      return response;
    } catch (e) {
      throw Exception('Error al obtener direcciones: $e');
    }
  }

  // Crear una nueva dirección en el backend (Mapea camelCase a la API)
  Future<Map<String, dynamic>> createDireccion({
    required String alias,
    required String callePrincipal,
    String? calleSecundaria,
    String? referencia,
  }) async {
    try {
      final data = {'alias': alias, 'callePrincipal': callePrincipal};

      if (calleSecundaria != null && calleSecundaria.trim().isNotEmpty) {
        data['calleSecundaria'] = calleSecundaria;
      }
      if (referencia != null && referencia.trim().isNotEmpty) {
        data['referencia'] = referencia;
      }

      final response = await _apiClient.post('/addresses', body: data);

      return response;
    } catch (e) {
      throw Exception('Error al crear dirección: $e');
    }
  }

  // Actualizar una dirección existente
  Future<Map<String, dynamic>> updateDireccion({
    required String id,
    String? alias,
    String? callePrincipal,
    String? calleSecundaria,
    String? referencia,
  }) async {
    try {
      final data = <String, dynamic>{};

      if (alias != null) data['alias'] = alias;
      if (callePrincipal != null) data['callePrincipal'] = callePrincipal;
      if (calleSecundaria != null) data['calleSecundaria'] = calleSecundaria;
      if (referencia != null) data['referencia'] = referencia;

      final response = await _apiClient.put('/addresses/$id', body: data);

      return response;
    } catch (e) {
      throw Exception('Error al actualizar dirección: $e');
    }
  }

  // Eliminar una dirección
  Future<void> deleteDireccion(String id) async {
    try {
      await _apiClient.delete('/addresses/$id');
    } catch (e) {
      throw Exception('Error al eliminar dirección: $e');
    }
  }
}
