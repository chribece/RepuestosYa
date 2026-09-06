import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';
import '../utils/app_logger.dart';
import '../models/part_catalog.dart';
import 'solicitud_service.dart';

class SolicitudRepository {
  final AppDatabase _db;
  static const String _lastSyncKey = 'repuestosya_last_solicitud_sync';

  SolicitudRepository(this._db);

  // Flujo reactivo para la UI
  Stream<List<SolicitudLocal>> watchTodas() {
    return _db.select(_db.solicitudes).watch();
  }

  // Borra tabla y reinserta datos frescos del servidor
  Future<void> reemplazarDesdeServidor(List<Solicitud> datos) async {
    try {
      debugPrint('SINCRO: Guardando ${datos.length} solicitudes en DB local');

      await _db.transaction(() async {
        // 1. Borrar solo lo que ya estaba sincronizado (para no tocar lo pendiente de envío offline)
        await (_db.delete(
          _db.solicitudes,
        )..where((t) => t.synced.equals(true))).go();

        // 2. Insertar los nuevos datos del servidor
        for (var s in datos) {
          final local = _mapToServerLocal(s);
          await _db
              .into(_db.solicitudes)
              .insert(local, mode: InsertMode.insertOrReplace);
        }
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
      debugPrint('SINCRO: Éxito total en base de datos');
    } catch (e) {
      debugPrint('SINCRO: Error al guardar en DB: $e');
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
  Future<void> insertarLocal(SolicitudLocal solicitud) async {
    await _db
        .into(_db.solicitudes)
        .insert(solicitud, mode: InsertMode.insertOrReplace);
  }

  // Marcar una solicitud como sincronizada (actualizando su ID si es necesario)
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

  Future<List<PartCategory>> obtenerCategoriasLocal() async {
    final rows = await _db.select(_db.categoriasCache).get();
    return rows
        .map<PartCategory>(
          (r) => PartCategory.fromJson(json.decode(r.dataJson)),
        )
        .toList();
  }

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

  Future<List<CatalogPart>> obtenerRepuestosLocal(String categoriaId) async {
    final rows = await (_db.select(
      _db.partesCache,
    )..where((t) => t.categoriaId.equals(categoriaId))).get();
    return rows
        .map((r) => CatalogPart.fromJson(json.decode(r.dataJson)))
        .toList();
  }

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

  Future<List<Map<String, dynamic>>> obtenerVehiculosLocal() async {
    final rows = await _db.select(_db.vehiculosCache).get();
    return rows
        .map<Map<String, dynamic>>(
          (r) => json.decode(r.dataJson) as Map<String, dynamic>,
        )
        .toList();
  }

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
  Future<DateTime?> ultimaSincronizacion() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString(_lastSyncKey);
    if (lastSyncStr != null) {
      return DateTime.tryParse(lastSyncStr);
    }
    return null;
  }
}
