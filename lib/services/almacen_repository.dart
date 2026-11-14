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

  /// Devuelve solo el perfil cuyo encargado es [userId]. Nunca un perfil de
  /// otra cuenta que haya usado el mismo dispositivo.
  Future<Almacen?> obtenerPerfilAlmacenLocal({required String userId}) async {
    try {
      final rows = await _db.select(_db.perfilAlmacenCache).get();
      for (final row in rows) {
        final almacen = Almacen.fromJson(json.decode(row.dataJson));
        if (almacen.encargadoId == userId) return almacen;
      }
      return null;
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
