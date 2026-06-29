import 'api_client.dart';

class SolicitudService {
  final ApiClient _apiClient = ApiClient();

  // Crear una nueva solicitud de repuesto
  Future<Map<String, dynamic>> crearSolicitud({
    required String clienteId,
    String? vehiculoId,
    required String piezaNombre,
    String? descripcion,
    String? fotoUrl,
    String? vinBusqueda,
    String? direccionEntregaId,
    bool esUrgente = false,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'pieza_nombre': piezaNombre,
      };

      // Solo agregar campos opcionales si tienen valor
      if (vehiculoId != null) data['vehiculo_id'] = vehiculoId;
      if (descripcion != null && descripcion.isNotEmpty) data['descripcion'] = descripcion;
      if (fotoUrl != null && fotoUrl.isNotEmpty) data['foto_url'] = fotoUrl;
      if (vinBusqueda != null && vinBusqueda.isNotEmpty) data['vin_busqueda'] = vinBusqueda;
      if (direccionEntregaId != null && direccionEntregaId.isNotEmpty) data['direccion_entrega_id'] = direccionEntregaId;
      if (esUrgente) data['es_urgente'] = esUrgente;

      final response = await _apiClient.post(
        '/solicitudes',
        body: data,
      );

      return response;
    } catch (e) {
      throw Exception('Error al crear solicitud: $e');
    }
  }

  // Obtener todas las solicitudes de un cliente
  Future<List<Map<String, dynamic>>> obtenerSolicitudesCliente(String clienteId) async {
    try {
      final response = await _apiClient.getList('/solicitudes');

      return response;
    } catch (e) {
      throw Exception('Error al obtener solicitudes: $e');
    }
  }

  // Obtener una solicitud por ID
  Future<Map<String, dynamic>> obtenerSolicitudPorId(String solicitudId) async {
    try {
      final response = await _apiClient.get('/solicitudes/$solicitudId');

      return response;
    } catch (e) {
      throw Exception('Error al obtener solicitud: $e');
    }
  }

  // Obtener solicitudes activas (para almacenes)
  Future<List<Map<String, dynamic>>> obtenerSolicitudesActivas() async {
    try {
      final response = await _apiClient.getList('/solicitudes/activas');

      return response;
    } catch (e) {
      throw Exception('Error al obtener solicitudes activas: $e');
    }
  }
}
