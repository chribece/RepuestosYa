import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:repuestosya/database/app_database.dart';
import 'package:repuestosya/models/part_catalog.dart';
import 'package:repuestosya/services/solicitud_repository.dart';

/// Pruebas del repositorio REAL de solicitudes contra Drift in-memory
/// (Fase 4 de docs/TESTING.md): espejo del servidor con borrado y gracia
/// temporal (R16/R17), upsert, sincronización de metadatos y limpieza.
void main() {
  late AppDatabase db;
  late SolicitudRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = SolicitudRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Solicitud serverSolicitud(String id, {String estado = 'en_proceso'}) {
    return Solicitud({
      'id': id,
      'pieza_nombre': 'Filtro $id',
      'estado': estado,
      'created_at': '2026-09-20T10:00:00.000Z',
      'updated_at': '2026-09-20T10:00:00.000Z',
    });
  }

  SolicitudLocal localRow({
    required String id,
    bool synced = true,
    DateTime? updatedAt,
  }) {
    return SolicitudLocal(
      id: id,
      vehiculoId: 'v1',
      piezaNombre: 'Local $id',
      estado: 'pendiente',
      createdAt: DateTime.now(),
      updatedAt: updatedAt ?? DateTime.now(),
      synced: synced,
    );
  }

  test('reemplazarDesdeServidor: upserta y el stream local emite', () async {
    // Listener inicial: la vista se entera del cambio (reactividad).
    final emitido = <List<SolicitudLocal>>[];
    final sub = repository.watchTodas().listen(emitido.add);
    addTearDown(sub.cancel);

    await repository.reemplazarDesdeServidor([
      serverSolicitud('s1'),
      serverSolicitud('s2'),
    ]);

    final filas = await repository.obtenerLocal();
    expect(filas.map((f) => f.id).toSet(), {'s1', 's2'});
    expect(filas.every((f) => f.synced), isTrue);
    // La pieza se mapea con el fallback displayPartName.
    expect(filas.first.piezaNombre, 'Filtro s1');

    // El stream emitió los datos (mismo comportamiento que Drift real).
    expect(emitido, isNotEmpty);
    expect(emitido.last.map((f) => f.id).toSet(), {'s1', 's2'});
  });

  test('borrado espejo con gracia: solo borra sincronizadas viejas', () async {
    final hora = DateTime.now();
    await repository.insertarLocal(
      localRow(
        id: 'vieja',
        synced: true,
        updatedAt: hora.subtract(const Duration(hours: 1)),
      ),
    );
    await repository.insertarLocal(
      localRow(
        id: 'reciente',
        synced: true,
        updatedAt: hora.subtract(const Duration(seconds: 5)),
      ),
    );
    // Pendiente de Outbox: nunca se borra por el espejo.
    await repository.insertarLocal(localRow(id: 'pendiente', synced: false));

    // El snapshot del servidor solo tiene 'nueva'.
    await repository.reemplazarDesdeServidor([serverSolicitud('nueva')]);

    final ids = (await repository.obtenerLocal()).map((f) => f.id).toSet();
    // 'vieja' (fuera de la gracia de 30 s) se borró; 'reciente' (dentro de
    // la gracia) se conserva; 'pendiente' (no sincronizada) se conserva.
    expect(ids, {'nueva', 'reciente', 'pendiente'});
  });

  test(
    'marcarSincronizado: reemplaza el id temporal por el id del servidor',
    () async {
      await repository.insertarLocal(localRow(id: 'temp-1', synced: false));

      await repository.marcarSincronizado('temp-1', serverSolicitud('srv-1'));

      final filas = await repository.obtenerLocal();
      expect(filas, hasLength(1));
      expect(filas.single.id, 'srv-1');
      expect(filas.single.clientId, isNull);
      expect(filas.single.synced, isTrue);
    },
  );

  group('metadatos (caché offline)', () {
    test('categorías y repuestos: roundtrip', () async {
      await repository.guardarCategorias([
        PartCategory(id: 'cat-1', nombre: 'Frenos', slug: 'frenos'),
      ]);
      await repository.guardarRepuestos('cat-1', [
        CatalogPart(
          id: 'rep-1',
          categoriaId: 'cat-1',
          nombre: 'Pastillas',
          slug: 'pastillas',
        ),
      ]);

      final categorias = await repository.obtenerCategoriasLocal();
      expect(categorias.single.nombre, 'Frenos');

      final repuestos = await repository.obtenerRepuestosLocal('cat-1');
      expect(repuestos.single.nombre, 'Pastillas');
    });

    test('vehículos y direcciones: roundtrip', () async {
      await repository.guardarVehiculos([
        {
          'id': 'v-1',
          'vin': 'X123',
          'modelos_vehiculo': {
            'nombre': 'Corolla',
            'marcas_vehiculo': {'nombre': 'Toyota'},
          },
        },
      ]);
      await repository.guardarDirecciones([
        {'id': 'd-1', 'alias': 'Casa', 'calle_principal': 'Av. 10'},
      ]);

      final vehiculos = await repository.obtenerVehiculosLocal();
      expect(vehiculos.single['id'], 'v-1');

      final direcciones = await repository.obtenerDireccionesLocal();
      expect(direcciones.single['alias'], 'Casa');
    });
  });

  test('clearAll: limpia solicitudes, outbox y cachés', () async {
    await repository.insertarLocal(localRow(id: 'x'));
    await repository.guardarCategorias([
      PartCategory(id: 'c', nombre: 'C', slug: 'c'),
    ]);
    await db
        .into(db.outbox)
        .insert(
          OutboxCompanion.insert(
            clientId: 'o-1',
            entityType: 'solicitud',
            operation: 'CREATE',
            payload: '{}',
            createdAt: DateTime.now(),
          ),
        );

    await repository.clearAll();

    expect(await repository.obtenerLocal(), isEmpty);
    expect(await db.select(db.outbox).get(), isEmpty);
    expect(await repository.obtenerCategoriasLocal(), isEmpty);
  });
}
