import 'api_client.dart';

class SolicitudService {
  final ApiClient _apiClient = ApiClient();

  // Obtener solicitudes paginadas para el flujo general del cliente
  Future<List<Map<String, dynamic>>> obtenerSolicitudesPaginadas({
    required String clienteId,
    required int page,
    required int limit,
  }) async {
    try {
      final response = await _apiClient.getList(
        '/solicitudes?cliente_id=$clienteId&page=$page&limit=$limit',
      );
      return response;
    } catch (e) {
      throw Exception('Error al obtener solicitudes paginadas: $e');
    }
  }
  // Método puente para compatibilidad con la vista Home
  Future<List<Map<String, dynamic>>> obtenerSolicitudesCliente(String clienteId) async {
    try {
      // Llama a la misma ruta pero con valores por defecto para evitar romper la vista anterior
      return await obtenerSolicitudesPaginadas(
        clienteId: clienteId,
        page: 1,
        limit: 50, // Un número alto para traer las principales
      );
    } catch (e) {
      throw Exception('Error en SolicitudService.obtenerSolicitudesCliente: $e');
    }
  }
  // Crear una nueva solicitud de repuesto (Rol Cliente)
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
        'cliente_id': clienteId,
        'pieza_nombre': piezaNombre,
        'es_urgente': esUrgente,
      };

      if (vehiculoId != null) data['vehiculo_id'] = vehiculoId;
      if (descripcion != null && descripcion.isNotEmpty) data['descripcion'] = descripcion;
      if (fotoUrl != null && fotoUrl.isNotEmpty) data['foto_url'] = fotoUrl;
      if (vinBusqueda != null && vinBusqueda.isNotEmpty) data['vin_busqueda'] = vinBusqueda;
      if (direccionEntregaId != null) data['direccion_entrega_id'] = direccionEntregaId;

      final response = await _apiClient.post(
        '/solicitudes',
        body: data,
        requireAuth: true,
      );

      return response;
    } catch (e) {
      throw Exception('Error al crear la solicitud: $e');
    }
  }

  // =========================================================================
  // MÓDULO DE ALMACENES - FEED DE TRABAJO Y CREACIÓN DE COTIZACIONES
  // =========================================================================

  // Obtener solicitudes activas para el feed del almacén
  Future<List<Map<String, dynamic>>> obtenerSolicitudesActivas() async {
    try {
      final response = await _apiClient.getList('/solicitudes/activas');
      return response;
    } catch (e) {
      throw Exception('Error al obtener solicitudes activas: $e');
    }
  }

  // Crear una nueva cotización asociada a una solicitud (Consistente con fotoUrl del cliente)
  Future<Map<String, dynamic>> crearCotizacion({
    required String solicitudId,
    required String almacenId,
    required double precio,
    String? notas,
    String? fotoUrl, // Recibe la URL pública como String desde el Storage
  }) async {
    try {
      final Map<String, dynamic> data = {
        'solicitud_id': solicitudId,
        'almacen_id': almacenId,
        'precio': precio,
      };

      // Inyección dinámica de campos opcionales sin duplicaciones
      if (notas != null && notas.isNotEmpty) {
        data['notas'] = notas;
      }
      if (fotoUrl != null && fotoUrl.isNotEmpty) {
        data['imagen_url'] = fotoUrl; // Mapeado a la columna real en la BD de Supabase
      }

      // Envía el JSON plano al backend sin mezclar lógica multipart redundante
      final response = await _apiClient.post(
        '/cotizaciones',
        body: data,
        requireAuth: true,
      );

      return response;
    } catch (e) {
      throw Exception('Error en SolicitudService.crearCotizacion: $e');
    }
  }
}