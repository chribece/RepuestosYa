import '../utils/api_error_handler.dart';
import '../utils/app_logger.dart';
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

  // Nuevos campos del catálogo
  String? get categoriaId => _data['categoria_id']?.toString();
  String? get repuestoId => _data['repuesto_id']?.toString();
  String? get repuestoNombreSnapshot => _data['repuesto_nombre_snapshot'];
  String? get descripcionProblema => _data['descripcion_problema'];

  // Nombre para mostrar (con fallback legacy)
  String get displayPartName => repuestoNombreSnapshot ?? piezaNombre;

  // Descripción para mostrar (con fallback legacy)
  String get displayDescription => descripcionProblema ?? descripcion ?? '';

  // Categoría embebida
  String? get categoriaNombre {
    final cat = _data['categorias_repuestos'];
    if (cat is Map) return cat['nombre']?.toString();
    return null;
  }

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
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        ApiErrorHandler.defaultMessage,
        technicalMessage: 'obtenerSolicitudesPaginadas: $e',
      );
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
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        ApiErrorHandler.defaultMessage,
        technicalMessage: 'obtenerSolicitudesCliente: $e',
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
    String? categoriaId,
    String? repuestoId,
    String? repuestoNombreSnapshot,
    String? descripcionProblema,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'pieza_nombre': piezaNombre,
        'es_urgente': esUrgente,
      };

      if (vehiculoId != null) data['vehiculo_id'] = vehiculoId;
      if (descripcion != null && descripcion.isNotEmpty) {
        data['descripcion'] = descripcion;
      }
      if (fotoUrl != null && fotoUrl.isNotEmpty) data['foto_url'] = fotoUrl;
      if (vinBusqueda != null && vinBusqueda.isNotEmpty) {
        data['vin_busqueda'] = vinBusqueda;
      }
      if (direccionEntregaId != null) {
        data['direccion_entrega_id'] = direccionEntregaId;
      }

      // Nuevos campos del catálogo
      if (categoriaId != null) data['categoria_id'] = categoriaId;
      if (repuestoId != null) data['repuesto_id'] = repuestoId;
      if (repuestoNombreSnapshot != null) {
        data['repuesto_nombre_snapshot'] = repuestoNombreSnapshot;
      }
      if (descripcionProblema != null) {
        data['descripcion_problema'] = descripcionProblema;
      }

      final response = await _apiClient.post(
        '/requests',
        body: data,
        requireAuth: true,
      );

      return response;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        ApiErrorHandler.defaultMessage,
        technicalMessage: 'crearSolicitud: $e',
      );
    }
  }

  // Obtener una solicitud específica por su ID
  Future<Map<String, dynamic>> obtenerSolicitudPorId(String id) async {
    try {
      final response = await _apiClient.get('/requests/$id');
      return response;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        ApiErrorHandler.defaultMessage,
        technicalMessage: 'obtenerSolicitudPorId: $e',
      );
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
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        ApiErrorHandler.defaultMessage,
        technicalMessage: 'obtenerSolicitudesActivas: $e',
      );
    }
  }

  // Obtener mis cotizaciones (Rol Almacén)
  Future<List<Map<String, dynamic>>> obtenerMisCotizaciones() async {
    try {
      final response = await _apiClient.getList('/quotations/my-quotations');
      return response;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        ApiErrorHandler.defaultMessage,
        technicalMessage: 'obtenerMisCotizaciones: $e',
      );
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
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        ApiErrorHandler.defaultMessage,
        technicalMessage: 'crearCotizacion: $e',
      );
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
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        ApiErrorHandler.defaultMessage,
        technicalMessage: 'obtenerCotizacionesRecibidas: $e',
      );
    }
  }

  // Aceptar una cotización específica (Rol Cliente)
  Future<Map<String, dynamic>> aceptarCotizacion(String cotizacionId) async {
    try {
      AppLogger.debug(
        'Llamando a POST /quotations/$cotizacionId/accept',
        name: 'SolicitudService',
      );
      final response = await _apiClient.post(
        '/quotations/$cotizacionId/accept',
        requireAuth: true,
      );
      AppLogger.debug(
        'Respuesta de aceptarCotizacion: $response - ordenId extraído: ${response['ordenId']}',
        name: 'SolicitudService',
      );
      return response;
    } on ApiException {
      rethrow;
    } catch (e) {
      AppLogger.error(
        'Error en aceptarCotizacion: $e',
        name: 'SolicitudService',
        error: e,
      );
      throw ApiException(
        ApiErrorHandler.defaultMessage,
        technicalMessage: 'aceptarCotizacion: $e',
      );
    }
  }

  // Rechazar una cotización específica (Rol Cliente)
  Future<Map<String, dynamic>> rechazarCotizacion(String cotizacionId) async {
    try {
      AppLogger.debug(
        'Llamando a POST /quotations/$cotizacionId/reject',
        name: 'SolicitudService',
      );
      final response = await _apiClient.post(
        '/quotations/$cotizacionId/reject',
        requireAuth: true,
      );
      AppLogger.debug('Respuesta exitosa: $response', name: 'SolicitudService');
      return response;
    } on ApiException {
      rethrow;
    } catch (e) {
      AppLogger.error(
        'Error en rechazarCotizacion: $e',
        name: 'SolicitudService',
        error: e,
      );
      throw ApiException(
        ApiErrorHandler.defaultMessage,
        technicalMessage: 'rechazarCotizacion: $e',
      );
    }
  }

  // Obtener estadísticas del cliente (Rol Cliente)
  Future<Map<String, dynamic>> obtenerEstadisticasCliente() async {
    try {
      final response = await _apiClient.get('/requests/stats');
      return response;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        ApiErrorHandler.defaultMessage,
        technicalMessage: 'obtenerEstadisticasCliente: $e',
      );
    }
  }

  // Obtener mis órdenes de compra (Rol Cliente)
  Future<List<Map<String, dynamic>>> obtenerMisOrdenes({
    required int page,
    required int limit,
  }) async {
    try {
      final response = await _apiClient.getList(
        '/orders?page=$page&limit=$limit',
      );
      return response;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        ApiErrorHandler.defaultMessage,
        technicalMessage: 'obtenerMisOrdenes: $e',
      );
    }
  }
}
