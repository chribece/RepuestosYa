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
        '/requests?page=$page&limit=$limit',
      );
      return response;
    } catch (e) {
      throw Exception('Error al obtener solicitudes paginadas: $e');
    }
  }

  // Método puente para compatibilidad con la vista Home
  Future<List<Map<String, dynamic>>> obtenerSolicitudesCliente(String clienteId) async {
    try {
      return await obtenerSolicitudesPaginadas(
        clienteId: clienteId,
        page: 1,
        limit: 50,
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
        'pieza_nombre': piezaNombre,
        'es_urgente': esUrgente,
      };

      if (vehiculoId != null) data['vehiculo_id'] = vehiculoId;
      if (descripcion != null && descripcion.isNotEmpty) data['descripcion'] = descripcion;
      if (fotoUrl != null && fotoUrl.isNotEmpty) data['foto_url'] = fotoUrl;
      if (vinBusqueda != null && vinBusqueda.isNotEmpty) data['vin_busqueda'] = vinBusqueda;
      if (direccionEntregaId != null) data['direccion_entrega_id'] = direccionEntregaId;

      final response = await _apiClient.post(
        '/requests',
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
      final response = await _apiClient.getList('/requests/active');
      return response;
    } catch (e) {
      throw Exception('Error al obtener solicitudes activas: $e');
    }
  }

  // Crear una nueva cotización asociada a una solicitud
  Future<Map<String, dynamic>> crearCotizacion({
    required String solicitudId,
    required String almacenId,
    required double precio,
    String? notas,
    String? fotoUrl,
    required String tiempoEntrega,
    String? estadoRepuesto, 
  }) async {
    try {
      final Map<String, dynamic> data = {
        'solicitud_id': solicitudId,
        'almacen_id': almacenId,
        'precio_venta': precio,
        'tiempo_entrega_estimado': tiempoEntrega,
      };

      if (notas != null && notas.isNotEmpty) {
        data['notas_adicionales'] = notas;
      }
      if (fotoUrl != null && fotoUrl.isNotEmpty) {
        data['foto_evidencia_url'] = fotoUrl;
      }
      
      if (estadoRepuesto != null && estadoRepuesto.isNotEmpty) {
        data['condicion_repuesto'] = estadoRepuesto;
        data['estado_repuesto'] = estadoRepuesto;
        data['condicion'] = estadoRepuesto;
      }

      final response = await _apiClient.post(
        '/quotations',
        body: data,
        requireAuth: true,
      );

      return response;
    } catch (e) {
      throw Exception('Error en SolicitudService.crearCotizacion: $e');
    }
  }

  // Obtener cotizaciones recibidas para una solicitud específica (Rol Cliente)
  Future<List<Map<String, dynamic>>> obtenerCotizacionesRecibidas(String solicitudId) async {
    try {
      final response = await _apiClient.getList('/quotations/request/$solicitudId');
      return response;
    } catch (e) {
      throw Exception('Error al obtener cotizaciones recibidas: $e');
    }
  }

  // Aceptar una cotización específica (Rol Cliente)
  Future<Map<String, dynamic>> aceptarCotizacion(String cotizacionId) async {
    try {
      final response = await _apiClient.put(
        '/quotations/$cotizacionId/status',
        body: {'estado': 'aceptada'},
        requireAuth: true,
      );
      return response;
    } catch (e) {
      throw Exception('Error al aceptar cotización: $e');
    }
  }

  // Rechazar una cotización específica (Rol Cliente)
  Future<Map<String, dynamic>> rechazarCotizacion(String cotizacionId) async {
    try {
      final response = await _apiClient.put(
        '/quotations/$cotizacionId/status',
        body: {'estado': 'rechazada'},
        requireAuth: true,
      );
      return response;
    } catch (e) {
      throw Exception('Error al rechazar cotización: $e');
    }
  }
}