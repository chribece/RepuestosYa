import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:repuestosya/models/part_catalog.dart';
import 'package:repuestosya/providers/solicitudes_provider.dart';
import 'package:repuestosya/services/solicitud_repository.dart';

/// Pruebas del [SolicitudesProvider] con un contrato de repositorio falso:
/// sincronización online/offline, guard anti-concurrencia y el hecho de que
/// un fallo del repositorio NO rompe al provider (riesgo R15 de
/// docs/TESTING.md: la UI no se entera del error).
void main() {
  SolicitudLocal localSolicitud({
    String id = 's1',
    String estado = 'pendiente',
    bool synced = true,
  }) {
    return SolicitudLocal(
      id: id,
      vehiculoId: 'v1',
      piezaNombre: 'Filtro de aceite',
      estado: estado,
      descripcion: 'ruido al frenar',
      createdAt: DateTime(2026, 9, 20),
      updatedAt: DateTime(2026, 9, 20),
      synced: synced,
    );
  }

  group('estado inicial (reactividad del stream local)', () {
    test(
      'el constructor escucha watchTodas y expone las solicitudes',
      () async {
        final fake = _FakeSolicitudRepository();
        final provider = SolicitudesProvider(fake);
        addTearDown(provider.dispose);

        fake.emiteSolicitudes([localSolicitud()]);
        await pumpEventQueue();

        expect(provider.solicitudes, hasLength(1));
        expect(provider.solicitudes.single.piezaNombre, 'Filtro de aceite');
      },
    );
  });

  group('refreshFromServer', () {
    test('online: obtiene del servidor y espeja en el repositorio', () async {
      final fake = _FakeSolicitudRepository()
        ..setOnline(true)
        ..respuestaServidor = [
          {'id': 'srv-1', 'pieza_nombre': 'Bujías'},
        ];
      final provider = SolicitudesProvider(fake);
      addTearDown(provider.dispose);

      await provider.refreshFromServer();

      expect(fake.llamadasObtener, 1);
      expect(fake.ultimosDatosRecibidos, hasLength(1));
      expect(fake.ultimosDatosRecibidos!.single.id, 'srv-1');
      expect(provider.isLoading, isFalse);
      expect(provider.isOffline, isFalse);
    });

    test('offline: no llama al servidor y marca isOffline', () async {
      final fake = _FakeSolicitudRepository()..setOnline(false);
      final provider = SolicitudesProvider(fake);
      addTearDown(provider.dispose);

      await provider.refreshFromServer();

      expect(fake.llamadasObtener, 0);
      expect(provider.isOffline, isTrue);
      expect(provider.isLoading, isFalse);
    });

    test('fallo del repositorio: no lanza y deja isLoading en false', () async {
      final fake = _FakeSolicitudRepository()
        ..setOnline(true)
        ..falloAlObtener = Exception('500 del backend');
      final provider = SolicitudesProvider(fake);
      addTearDown(provider.dispose);

      await provider.refreshFromServer(); // no debe lanzar

      expect(provider.isLoading, isFalse);
    });

    test(
      'guard anti-concurrencia: dos llamadas seguidas hacen un solo fetch',
      () async {
        final fake = _FakeSolicitudRepository()
          ..setOnline(true)
          ..respuestaServidor = [
            {'id': 'srv-1', 'pieza_nombre': 'Bujías'},
          ];
        final provider = SolicitudesProvider(fake);
        addTearDown(provider.dispose);

        final primera = provider.refreshFromServer();
        final segunda = provider.refreshFromServer();
        await Future.wait([primera, segunda]);

        expect(fake.llamadasObtener, 1);
      },
    );
  });
}

/// Doble del contrato de repositorio de solicitudes: streams controlables y
/// respuestas scriptables, sin red ni plugins.
class _FakeSolicitudRepository implements SolicitudRepositoryContract {
  final StreamController<List<SolicitudLocal>> _solicitudes =
      StreamController<List<SolicitudLocal>>.broadcast();
  final StreamController<bool> _offline = StreamController<bool>.broadcast();

  bool _esOffline = false;
  List<Map<String, dynamic>> respuestaServidor = [];
  Object? falloAlObtener;
  int llamadasObtener = 0;
  List<Solicitud>? ultimosDatosRecibidos;

  void setOnline(bool online) => _esOffline = !online;

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
  Future<DateTime?> ultimaSincronizacion() async => null;

  @override
  Future<List<Map<String, dynamic>>> obtenerSolicitudesCliente(
    String clienteId,
  ) async {
    llamadasObtener++;
    if (falloAlObtener != null) throw falloAlObtener!;
    return respuestaServidor;
  }

  @override
  Future<void> reemplazarDesdeServidor(List<Solicitud> datos) async {
    ultimosDatosRecibidos = datos;
  }

  @override
  Future<void> sincronizarMetadatos() async {}

  // Métodos del contrato no ejercitados por estos tests.

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
