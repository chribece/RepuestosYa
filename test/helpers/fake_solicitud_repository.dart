import 'dart:async';

import 'package:repuestosya/models/part_catalog.dart';
import 'package:repuestosya/services/solicitud_repository.dart';

/// Fuente de datos falsa del contrato de solicitudes (Fase 4 de
/// docs/TESTING.md, usada ya en la Fase 2): streams controlables, respuestas
/// scriptables y conteo de llamadas — sin red ni plugins.
///
/// `reemplazarDesdeServidor` emite al stream `watchTodas` (igual que el
/// repositorio real escribe en Drift y la UI reacciona), para que los widget
/// tests de los 4 estados del Home sean deterministas.
class FakeSolicitudRepository implements SolicitudRepositoryContract {
  final StreamController<List<SolicitudLocal>> _solicitudes =
      StreamController<List<SolicitudLocal>>.broadcast();
  final StreamController<bool> _offline = StreamController<bool>.broadcast();

  bool _esOffline = false;
  List<Map<String, dynamic>> respuestaServidor = [];
  Object? falloAlObtener;
  DateTime? _ultimaSincronizacion;
  int llamadasObtener = 0;
  List<Solicitud>? ultimosDatosRecibidos;

  Completer<void>? _respuestaBloqueada;

  /// La siguiente llamada a `obtenerSolicitudesCliente` queda pendiente para
  /// siempre (estado de carga persistente); [liberarRespuesta] la completa.
  void bloquearRespuesta() {
    _respuestaBloqueada = Completer<void>();
  }

  void liberarRespuesta() {
    _respuestaBloqueada?.complete();
  }

  /// Lo que el "servidor" devuelve tras una sincronización exitosa.
  void setRespuestaServidor(List<Map<String, dynamic>> datos) {
    respuestaServidor = datos;
  }

  /// Falla la siguiente llamada a `obtenerSolicitudesCliente`.
  void setFalloAlObtener(Object error) {
    falloAlObtener = error;
  }

  void setOnline(bool online) => _esOffline = !online;

  void setUltimaSincronizacion(DateTime? value) {
    _ultimaSincronizacion = value;
  }

  void emiteSolicitudes(List<SolicitudLocal> solicitudes) {
    _solicitudes.add(solicitudes);
  }

  void emiteOffline(bool offline) {
    _offline.add(offline);
  }

  @override
  Stream<List<SolicitudLocal>> watchTodas() => _solicitudes.stream;

  @override
  Stream<bool> watchOffline() => _offline.stream;

  @override
  Future<bool> isOffline() async => _esOffline;

  @override
  Future<DateTime?> ultimaSincronizacion() async => _ultimaSincronizacion;

  @override
  Future<List<Map<String, dynamic>>> obtenerSolicitudesCliente(
    String clienteId,
  ) async {
    llamadasObtener++;
    final bloqueo = _respuestaBloqueada;
    if (bloqueo != null) await bloqueo.future;
    if (falloAlObtener != null) throw falloAlObtener!;
    return respuestaServidor;
  }

  @override
  Future<void> reemplazarDesdeServidor(List<Solicitud> datos) async {
    ultimosDatosRecibidos = datos;
    // Igual que el repositorio real (Drift): la escritura dispara el stream.
    _solicitudes.add(datos.map((s) => _aLocal(s)).toList());
  }

  SolicitudLocal _aLocal(Solicitud s) {
    return SolicitudLocal(
      id: s.id,
      vehiculoId: s.toJson()['vehiculo_id']?.toString() ?? 'unknown',
      piezaNombre: s.displayPartName,
      categoriaId: s.categoriaId,
      repuestoId: s.repuestoId,
      estado: s.estado,
      descripcion: s.displayDescription,
      fotoUrl: s.fotoUrl,
      createdAt: s.createdAt ?? DateTime.now(),
      updatedAt: s.updatedAt ?? DateTime.now(),
      synced: true,
    );
  }

  @override
  Future<void> sincronizarMetadatos() async {}

  // Métodos del contrato no ejercitados por estas pruebas.

  @override
  Future<void> insertarLocal(SolicitudLocal solicitud) async {}

  @override
  Future<void> marcarSincronizado(String tempId, Solicitud serverData) async {}

  @override
  Future<void> guardarCategorias(List<PartCategory> categorias) async {}

  @override
  Future<List<PartCategory>> obtenerCategoriasLocal() async => [];

  @override
  Future<void> guardarRepuestos(
    String categoriaId,
    List<CatalogPart> repuestos,
  ) async {}

  @override
  Future<List<CatalogPart>> obtenerRepuestosLocal(String categoriaId) async =>
      [];

  @override
  Future<void> guardarVehiculos(List<Map<String, dynamic>> vehiculos) async {}

  @override
  Future<List<Map<String, dynamic>>> obtenerVehiculosLocal() async => [];

  @override
  Future<void> guardarDirecciones(
    List<Map<String, dynamic>> direcciones,
  ) async {}

  @override
  Future<List<Map<String, dynamic>>> obtenerDireccionesLocal() async => [];
}
