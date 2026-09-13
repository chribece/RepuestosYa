import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/app_database.dart';
import '../utils/app_logger.dart';
import '../models/part_catalog.dart';
import 'solicitud_service.dart';
import 'catalog_service.dart';
import 'vehiculo_service.dart';
import 'direccion_service.dart';

export '../database/app_database.dart' show SolicitudLocal;
export 'solicitud_service.dart' show Solicitud;

abstract class SolicitudRepositoryContract {
  Stream<List<SolicitudLocal>> watchTodas();
  Stream<bool> watchOffline();
  Future<bool> isOffline();
  Future<DateTime?> ultimaSincronizacion();
  Future<List<Map<String, dynamic>>> obtenerSolicitudesCliente(
    String clienteId,
  );
  Future<void> reemplazarDesdeServidor(List<Solicitud> datos);
  Future<void> sincronizarMetadatos();
  Future<void> insertarLocal(SolicitudLocal solicitud);
  Future<void> marcarSincronizado(String tempId, Solicitud serverData);
  Future<void> guardarCategorias(List<PartCategory> categorias);
  Future<List<PartCategory>> obtenerCategoriasLocal();
  Future<void> guardarRepuestos(
    String categoriaId,
    List<CatalogPart> repuestos,
  );
  Future<List<CatalogPart>> obtenerRepuestosLocal(String categoriaId);
  Future<void> guardarVehiculos(List<Map<String, dynamic>> vehiculos);
  Future<List<Map<String, dynamic>>> obtenerVehiculosLocal();
  Future<void> guardarDirecciones(List<Map<String, dynamic>> direcciones);
  Future<List<Map<String, dynamic>>> obtenerDireccionesLocal();
}

class SolicitudRepository implements SolicitudRepositoryContract {
  final AppDatabase _db;
  final SolicitudService _remoteSolicitud;
  final CatalogService _remoteCatalog;
  final VehiculoService _remoteVehiculos;
  final DireccionService _remoteDirecciones;
  static const String _lastSyncKey = 'repuestosya_last_solicitud_sync';

  /// Gracia para el borrado espejo: filas sincronizadas más recientes que
  /// esta ventana se conservan aunque no estén en el snapshot, para no perder
  /// una solicitud recién sincronizada durante la carrera pull/push.
  static const Duration _syncGrace = Duration(seconds: 30);

  SolicitudRepository(
    this._db, {
    SolicitudService? remoteSolicitud,
    CatalogService? remoteCatalog,
    VehiculoService? remoteVehiculos,
    DireccionService? remoteDirecciones,
  }) : _remoteSolicitud = remoteSolicitud ?? SolicitudService(),
       _remoteCatalog = remoteCatalog ?? CatalogService(),
       _remoteVehiculos = remoteVehiculos ?? VehiculoService(),
       _remoteDirecciones = remoteDirecciones ?? DireccionService();

  @override
  Stream<bool> watchOffline() {
    return Connectivity().onConnectivityChanged.map(
      (results) => results.contains(ConnectivityResult.none),
    );
  }

  @override
  Future<bool> isOffline() async {
    final results = await Connectivity().checkConnectivity();
    return results.contains(ConnectivityResult.none);
  }

  @override
  Future<List<Map<String, dynamic>>> obtenerSolicitudesCliente(
    String clienteId,
  ) {
    return _remoteSolicitud.obtenerSolicitudesCliente(clienteId);
  }

  @override
  Future<void> sincronizarMetadatos() async {
    final categorias = await _remoteCatalog.getPartCategories();
    await guardarCategorias(categorias);

    final vehiculos = await _remoteVehiculos.getVehiculos();
    await guardarVehiculos(vehiculos);

    final direcciones = await _remoteDirecciones.getDirecciones();
    await guardarDirecciones(direcciones);
  }

  // Flujo reactivo para la UI
  @override
  Stream<List<SolicitudLocal>> watchTodas() {
    return (_db.select(_db.solicitudes)..orderBy([
          // Orden determinista: más recientes primero. Sin ORDER BY, SQLite
          // devuelve por rowid físico y el INSERT OR REPLACE del upsert
          // reubica filas, haciendo que el take(3) del Home muestre
          // solicitudes "al azar" (la recién sincronizada podía desaparecer).
          (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
          (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
        ]))
        .watch();
  }

  /// Espeja los datos frescos del servidor contra la DB local.
  ///
  /// 1. **Borrado espejo con gracia temporal:** elimina las filas
  ///    sincronizadas que ya no existen en el snapshot (p. ej. una solicitud
  ///    borrada en Supabase), pero conserva las actualizadas en los últimos
  ///    [_syncGrace]: esas pueden ser una solicitud recién sincronizada por
  ///    SyncEngine que el snapshot (tomado antes del POST del outbox) aún no
  ///    incluye. Así el borrado remoto se refleja sin reintroducir la carrera
  ///    que hacía desaparecer solicitudes recién sincronizadas.
  /// 2. **UPSERT por id** de los datos del servidor: no toca las filas
  ///    pendientes de envío offline (synced = false).
  @override
  Future<void> reemplazarDesdeServidor(List<Solicitud> datos) async {
    try {
      AppLogger.info(
        'SINCRO: Guardando ${datos.length} solicitudes en DB local',
        name: 'SolicitudRepository',
      );

      await _db.transaction(() async {
        final ids = datos.map((s) => s.id).toSet();
        final graceCutoff = DateTime.now().subtract(_syncGrace);

        await (_db.delete(_db.solicitudes)..where(
              (t) =>
                  t.synced.equals(true) &
                  t.id.isNotIn(ids) &
                  t.updatedAt.isSmallerThanValue(graceCutoff),
            ))
            .go();

        // UPSERT: inserta/actualiza las solicitudes del servidor sin borrar
        // las locales (pendientes de outbox o recién sincronizadas).
        for (var s in datos) {
          final local = _mapToServerLocal(s);
          await _db
              .into(_db.solicitudes)
              .insert(local, mode: InsertMode.insertOrReplace);
        }
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
      AppLogger.info(
        'SINCRO: Éxito total en base de datos',
        name: 'SolicitudRepository',
      );
    } catch (e) {
      AppLogger.error(
        'SINCRO: Error al guardar en DB: $e',
        name: 'SolicitudRepository',
      );
    }
  }

  SolicitudLocal _mapToServerLocal(Solicitud s) {
    // Aseguramos que ningún campo obligatorio sea nulo para no romper SQLite
    return SolicitudLocal(
      id: s.id,
      clientId: null,
      vehiculoId: s.toJson()['vehiculo_id']?.toString() ?? 'unknown',
      piezaNombre: s.displayPartName.isEmpty
          ? 'Repuesto sin nombre'
          : s.displayPartName,
      categoriaId: s.categoriaId,
      repuestoId: s.repuestoId,
      estado: s.estado.isEmpty ? 'en_proceso' : s.estado,
      descripcion: s.displayDescription,
      fotoUrl: s.fotoUrl,
      createdAt: s.createdAt ?? DateTime.now(),
      updatedAt: s.updatedAt ?? DateTime.now(),
      synced: true,
    );
  }

  // Insertar una solicitud local (usado para offline creation)
  @override
  Future<void> insertarLocal(SolicitudLocal solicitud) async {
    await _db
        .into(_db.solicitudes)
        .insert(solicitud, mode: InsertMode.insertOrReplace);
  }

  // Marcar una solicitud como sincronizada (actualizando su ID si es necesario)
  @override
  Future<void> marcarSincronizado(String tempId, Solicitud serverData) async {
    await _db.transaction(() async {
      // 1. Borrar la entrada temporal si el ID cambió
      if (tempId != serverData.id) {
        await (_db.delete(
          _db.solicitudes,
        )..where((t) => t.id.equals(tempId))).go();
      }

      // 2. Insertar/Actualizar con los datos finales del servidor
      final local = _mapToServerLocal(serverData);
      await _db
          .into(_db.solicitudes)
          .insert(local, mode: InsertMode.insertOrReplace);
    });
  }

  // --- METADATOS CACHE ---

  @override
  Future<void> guardarCategorias(List<PartCategory> categorias) async {
    await _db.transaction(() async {
      await _db.delete(_db.categoriasCache).go();
      for (var cat in categorias) {
        await _db
            .into(_db.categoriasCache)
            .insert(
              CategoriasCacheCompanion.insert(
                id: cat.id,
                nombre: cat.nombre,
                slug: cat.slug,
                dataJson: json.encode(cat.toJson()),
              ),
            );
      }
    });
  }

  @override
  Future<List<PartCategory>> obtenerCategoriasLocal() async {
    final rows = await _db.select(_db.categoriasCache).get();
    return rows
        .map<PartCategory>(
          (r) => PartCategory.fromJson(json.decode(r.dataJson)),
        )
        .toList();
  }

  @override
  Future<void> guardarRepuestos(
    String categoriaId,
    List<CatalogPart> repuestos,
  ) async {
    await _db.transaction(() async {
      // Borramos solo los repuestos de ESTA categoría para refrescarla
      await (_db.delete(
        _db.partesCache,
      )..where((t) => t.categoriaId.equals(categoriaId))).go();
      for (var p in repuestos) {
        await _db
            .into(_db.partesCache)
            .insert(
              PartesCacheCompanion.insert(
                id: p.id,
                categoriaId: p.categoriaId,
                nombre: p.nombre,
                dataJson: json.encode(p.toJson()),
              ),
            );
      }
    });
  }

  @override
  Future<List<CatalogPart>> obtenerRepuestosLocal(String categoriaId) async {
    final rows = await (_db.select(
      _db.partesCache,
    )..where((t) => t.categoriaId.equals(categoriaId))).get();
    return rows
        .map((r) => CatalogPart.fromJson(json.decode(r.dataJson)))
        .toList();
  }

  @override
  Future<void> guardarVehiculos(List<Map<String, dynamic>> vehiculos) async {
    await _db.transaction(() async {
      await _db.delete(_db.vehiculosCache).go();
      for (var v in vehiculos) {
        final id = v['id']?.toString() ?? '';
        final modelo = v['modelos_vehiculo'] as Map<String, dynamic>?;
        final marca = modelo?['marcas_vehiculo'] as Map<String, dynamic>?;
        final nombre = marca != null && modelo != null
            ? '${marca['nombre']} ${modelo['nombre']}'
            : 'Vehículo';

        await _db
            .into(_db.vehiculosCache)
            .insert(
              VehiculosCacheCompanion.insert(
                id: id,
                nombre: nombre,
                vin: v['vin']?.toString() ?? '',
                dataJson: json.encode(v),
              ),
            );
      }
    });
  }

  @override
  Future<List<Map<String, dynamic>>> obtenerVehiculosLocal() async {
    final rows = await _db.select(_db.vehiculosCache).get();
    return rows
        .map<Map<String, dynamic>>(
          (r) => json.decode(r.dataJson) as Map<String, dynamic>,
        )
        .toList();
  }

  @override
  Future<void> guardarDirecciones(
    List<Map<String, dynamic>> direcciones,
  ) async {
    await _db.transaction(() async {
      await _db.delete(_db.direccionesCache).go();
      for (var d in direcciones) {
        await _db
            .into(_db.direccionesCache)
            .insert(
              DireccionesCacheCompanion.insert(
                id: d['id']?.toString() ?? '',
                alias: d['alias']?.toString() ?? 'Dirección',
                detalle: d['calle_principal']?.toString() ?? '',
                dataJson: json.encode(d),
              ),
            );
      }
    });
  }

  @override
  Future<List<Map<String, dynamic>>> obtenerDireccionesLocal() async {
    final rows = await _db.select(_db.direccionesCache).get();
    return rows
        .map<Map<String, dynamic>>(
          (r) => json.decode(r.dataJson) as Map<String, dynamic>,
        )
        .toList();
  }

  // Borrar todas las tablas (para logout)
  Future<void> clearAll() async {
    try {
      await _db.transaction(() async {
        await _db.delete(_db.solicitudes).go();
        await _db.delete(_db.outbox).go();
        await _db.delete(_db.categoriasCache).go();
        await _db.delete(_db.vehiculosCache).go();
        await _db.delete(_db.direccionesCache).go();
        await _db.delete(_db.perfilAlmacenCache).go();
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastSyncKey);
      AppLogger.info(
        'Tablas locales limpiadas con éxito',
        name: 'SolicitudRepository',
      );
    } catch (e) {
      AppLogger.error(
        'Error al limpiar tablas locales: $e',
        name: 'SolicitudRepository',
      );
      // Intentar borrar sin transacción si falla la transacción
      try {
        await _db.delete(_db.solicitudes).go();
        await _db.delete(_db.outbox).go();
      } catch (_) {}
    }
  }

  Future<List<SolicitudLocal>> obtenerLocal() async {
    return await _db.select(_db.solicitudes).get();
  }

  // Marca de la última sincronización exitosa
  @override
  Future<DateTime?> ultimaSincronizacion() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString(_lastSyncKey);
    if (lastSyncStr != null) {
      return DateTime.tryParse(lastSyncStr);
    }
    return null;
  }
}
