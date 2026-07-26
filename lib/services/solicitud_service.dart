import 'api_client.dart';

class Solicitud {
  final Map<String, dynamic> _data;

  Solicitud(this._data);

  String get id => _data['id']?.toString() ?? '';
  String get piezaNombre => _data['pieza_nombre'] ?? '';
  String? get descripcion => _data['descripcion'];
  String? get fotoUrl => _data['foto_url'];
  String? get vinBusqueda => _data['vin_busqueda'];
  bool get esUrgente => _data['es_urgente'] == true;
  String get estado => _data['estado'] ?? '';
  String get clienteId => _data['cliente_id']?.toString() ?? '';
  DateTime? get createdAt {
    final dateStr = _data['created_at'];
    if (dateStr != null) {
      return DateTime.tryParse(dateStr);
    }
    return null;
  }

  // Vehículo anidado
  Map<String, dynamic>? get vehiculo => _data['vehiculos_cliente'];
  Map<String, dynamic>? get modelo => vehiculo?['modelos_vehiculo'];
  Map<String, dynamic>? get marca => modelo?['marcas_vehiculo'];

  // Cotizaciones (lazy loading - solo count)
  int get cantidadCotizaciones {
    final cotizaciones = _data['cotizaciones'];
    if (cotizaciones is List && cotizaciones.isNotEmpty) {
      return cotizaciones.first['count'] ?? 0;
    }
    return 0;
  }

  Map<String, dynamic> toJson() => _data;
}

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
  Future<List<Map<String, dynamic>>> obtenerSolicitudesCliente(
    String clienteId,
  ) async {
    try {
      return await obtenerSolicitudesPaginadas(
        clienteId: clienteId,
        page: 1,
        limit: 50,
      );
    } catch (e) {
      throw Exception(
        'Error en SolicitudService.obtenerSolicitudesCliente: $e',
      );
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
      if (descripcion != null && descripcion.isNotEmpty)
        data['descripcion'] = descripcion;
      if (fotoUrl != null && fotoUrl.isNotEmpty) data['foto_url'] = fotoUrl;
      if (vinBusqueda != null && vinBusqueda.isNotEmpty)
        data['vin_busqueda'] = vinBusqueda;
      if (direccionEntregaId != null)
        data['direccion_entrega_id'] = direccionEntregaId;

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

  // Obtener mis cotizaciones (Rol Almacén)
  Future<List<Map<String, dynamic>>> obtenerMisCotizaciones() async {
    try {
      final response = await _apiClient.getList('/quotations/my-quotations');
      return response;
    } catch (e) {
      throw Exception('Error al obtener mis cotizaciones: $e');
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
  Future<List<Map<String, dynamic>>> obtenerCotizacionesRecibidas(
    String solicitudId,
  ) async {
    try {
      final response = await _apiClient.getList(
        '/quotations/request/$solicitudId',
      );
      return response;
    } catch (e) {
      throw Exception('Error al obtener cotizaciones recibidas: $e');
    }
  }

  // Aceptar una cotización específica (Rol Cliente)
  Future<Map<String, dynamic>> aceptarCotizacion(String cotizacionId) async {
    try {
      print(
        'SolicitudService: Llamando a POST /quotations/$cotizacionId/accept',
      );
      final response = await _apiClient.post(
        '/quotations/$cotizacionId/accept',
        requireAuth: true,
      );
      print('SolicitudService: Respuesta de aceptarCotizacion: $response');
      print('SolicitudService: ordenId extraído: ${response['ordenId']}');
      return response;
    } catch (e) {
      print('SolicitudService: Error en aceptarCotizacion: $e');
      throw Exception('Error al aceptar cotización: $e');
    }
  }

  // Rechazar una cotización específica (Rol Cliente)
  Future<Map<String, dynamic>> rechazarCotizacion(String cotizacionId) async {
    try {
      print(
        'SolicitudService: Llamando a POST /quotations/$cotizacionId/reject',
      );
      final response = await _apiClient.post(
        '/quotations/$cotizacionId/reject',
        requireAuth: true,
      );
      print('SolicitudService: Respuesta exitosa: $response');
      return response;
    } catch (e) {
      print('SolicitudService: Error en rechazarCotizacion: $e');
      throw Exception('Error al rechazar cotización: $e');
    }
  }
}
