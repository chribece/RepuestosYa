import 'dart:async';

import 'package:repuestosya/models/part_catalog.dart';
import 'package:repuestosya/services/almacen_service.dart';
import 'package:repuestosya/services/catalog_service.dart';
import 'package:repuestosya/services/direccion_service.dart';
import 'package:repuestosya/services/solicitud_service.dart';
import 'package:repuestosya/services/vehiculo_service.dart';

/// Dobles de los servicios usados por las pantallas del flujo crítico
/// (Crear Solicitud y Dashboard de Almacén). Subclases con respuestas
/// scriptables y contadores de llamadas: verifican QUE la llamada se dispara
/// (o NO se dispara) sin tocar la red.

class FakeSolicitudService extends SolicitudService {
  int crearSolicitudCalls = 0;
  int crearCotizacionCalls = 0;
  int estadisticasCalls = 0;
  int solicitudesActivasCalls = 0;
  int misCotizacionesCalls = 0;

  Map<String, dynamic>? respuestaCrear;
  Object? falloAlCrear;
  Object? falloAlCrearCotizacion;
  Map<String, dynamic> respuestaEstadisticas = {};
  List<Map<String, dynamic>> respuestaActivas = [];
  List<Map<String, dynamic>> respuestaMisCotizaciones = [];

  /// Parámetros de la última llamada a [crearSolicitud].
  Map<String, dynamic>? ultimaLlamadaCrear;

  /// Idempotency keys recibidas en [crearSolicitud] (para verificar que son
  /// estables entre reintentos del SyncEngine).
  final List<String?> idempotencyKeysCrear = [];

  /// Idempotency keys recibidas en [crearCotizacion].
  final List<String?> idempotencyKeysCotizacion = [];

  @override
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
    String? idempotencyKey,
    double? latitude,
    double? longitude,
    String? coordenadasFuente,
  }) async {
    crearSolicitudCalls++;
    idempotencyKeysCrear.add(idempotencyKey);
    ultimaLlamadaCrear = {
      'clienteId': clienteId,
      'vehiculoId': vehiculoId,
      'piezaNombre': piezaNombre,
      'descripcion': descripcion,
      'fotoUrl': fotoUrl,
      'direccionEntregaId': direccionEntregaId,
      'esUrgente': esUrgente,
      'categoriaId': categoriaId,
      'repuestoId': repuestoId,
      'repuestoNombreSnapshot': repuestoNombreSnapshot,
      'descripcionProblema': descripcionProblema,
      'latitude': latitude,
      'longitude': longitude,
      'coordenadasFuente': coordenadasFuente,
    };
    if (falloAlCrear != null) throw falloAlCrear!;
    return respuestaCrear ?? {'id': 'srv-1'};
  }

  @override
  Future<Map<String, dynamic>> crearCotizacion({
    required String solicitudId,
    required String almacenId,
    required double precio,
    String? notas,
    String? fotoUrl,
    required String tiempoEntrega,
    String? estadoRepuesto,
    String? idempotencyKey,
  }) async {
    crearCotizacionCalls++;
    idempotencyKeysCotizacion.add(idempotencyKey);
    if (falloAlCrearCotizacion != null) throw falloAlCrearCotizacion!;
    return {'id': 'cot-srv-1'};
  }

  @override
  Future<Map<String, dynamic>> obtenerEstadisticasCliente() async {
    estadisticasCalls++;
    return respuestaEstadisticas;
  }

  @override
  Future<List<Map<String, dynamic>>> obtenerSolicitudesActivas() async {
    solicitudesActivasCalls++;
    return respuestaActivas;
  }

  @override
  Future<List<Map<String, dynamic>>> obtenerMisCotizaciones() async {
    misCotizacionesCalls++;
    return respuestaMisCotizaciones;
  }
}

class FakeVehiculoService extends VehiculoService {
  List<Map<String, dynamic>> respuestaVehiculos = [];
  Object? falloAlObtener;

  @override
  Future<List<Map<String, dynamic>>> getVehiculos() async {
    if (falloAlObtener != null) throw falloAlObtener!;
    return respuestaVehiculos;
  }
}

class FakeDireccionService extends DireccionService {
  List<Map<String, dynamic>> respuestaDirecciones = [];
  Object? falloAlObtener;

  @override
  Future<List<Map<String, dynamic>>> getDirecciones() async {
    if (falloAlObtener != null) throw falloAlObtener!;
    return respuestaDirecciones;
  }
}

class FakeCatalogService extends CatalogService {
  List<PartCategory> respuestaCategorias = [];
  List<CatalogPart> respuestaPartes = [];

  @override
  Future<List<PartCategory>> getPartCategories() async {
    return respuestaCategorias;
  }

  @override
  Future<List<CatalogPart>> getParts({
    String? categoryId,
    String? query,
  }) async {
    return respuestaPartes;
  }
}

class FakeAlmacenService extends AlmacenService {
  FakeAlmacenService() : super(null);

  bool respuestaTienePerfil = true;
  Map<String, dynamic>? respuestaMiAlmacen;
  Object? falloAlValidar;

  /// La validación del perfil queda pendiente para siempre (estado de carga).
  bool bloquearValidacion = false;

  @override
  Future<bool> hasWarehouseProfile() async {
    if (bloquearValidacion) {
      // Nunca completa: simula la respuesta de red lenta.
      // ignore: avoid_slow_async_io
      return Completer<bool>().future;
    }
    if (falloAlValidar != null) throw falloAlValidar!;
    return respuestaTienePerfil;
  }

  @override
  Future<Map<String, dynamic>?> obtenerMiAlmacen() async {
    return respuestaMiAlmacen;
  }
}
