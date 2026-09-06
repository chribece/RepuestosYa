import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../models/almacen.dart';
import '../utils/app_logger.dart';

class AlmacenRepository {
  final AppDatabase _db;

  AlmacenRepository(this._db);

  Future<void> guardarPerfilAlmacen(Almacen almacen) async {
    try {
      await _db
          .into(_db.perfilAlmacenCache)
          .insert(
            PerfilAlmacenCacheCompanion.insert(
              id: almacen.id,
              nombreComercial: almacen.nombreComercial,
              verificationStatus: almacen.verificationStatus,
              dataJson: json.encode(almacen.toJson()),
              updatedAt: DateTime.now(),
            ),
            mode: InsertMode.insertOrReplace,
          );
    } catch (e) {
      AppLogger.error(
        'Error al guardar perfil de almacén en caché',
        name: 'AlmacenRepository',
        error: e,
      );
    }
  }

  Future<Almacen?> obtenerPerfilAlmacenLocal() async {
    try {
      final rows = await _db.select(_db.perfilAlmacenCache).get();
      if (rows.isEmpty) return null;

      // Tomamos el primero (solo debería haber uno por encargado en teoría,
      // pero el id es la PK del almacén)
      final row = rows.first;
      return Almacen.fromJson(json.decode(row.dataJson));
    } catch (e) {
      AppLogger.error(
        'Error al obtener perfil de almacén local',
        name: 'AlmacenRepository',
        error: e,
      );
      return null;
    }
  }

  Future<void> clearAll() async {
    try {
      await _db.delete(_db.perfilAlmacenCache).go();
    } catch (e) {
      AppLogger.error(
        'Error al limpiar PerfilAlmacenCache',
        name: 'AlmacenRepository',
        error: e,
      );
    }
  }
}
