import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../utils/app_logger.dart';

export '../database/app_database.dart' show OutboxData;

class OutboxService {
  final AppDatabase _db;
  final _uuid = const Uuid();

  OutboxService(this._db);

  Future<String> enqueue({
    required String entityType,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    final clientId = _uuid.v4();
    final entry = _buildEntry(
      clientId: clientId,
      entityType: entityType,
      operation: operation,
      payload: payload,
    );

    await _db.into(_db.outbox).insert(entry);
    return clientId;
  }

  /// Guarda Outbox y la solicitud local en una única transacción Drift.
  /// Si cualquiera de las dos inserciones falla, ninguna queda persistida.
  Future<String> enqueueSolicitud({
    required Map<String, dynamic> payload,
    required SolicitudLocal Function(String clientId) localRequest,
  }) async {
    final clientId = _uuid.v4();
    final entry = _buildEntry(
      clientId: clientId,
      entityType: 'solicitud',
      operation: 'CREATE',
      payload: payload,
    );

    await _db.transaction(() async {
      await _db.into(_db.outbox).insert(entry);
      await _db
          .into(_db.solicitudes)
          .insert(localRequest(clientId), mode: InsertMode.insertOrReplace);
    });
    return clientId;
  }

  OutboxCompanion _buildEntry({
    required String clientId,
    required String entityType,
    required String operation,
    required Map<String, dynamic> payload,
  }) {
    return OutboxCompanion.insert(
      clientId: clientId,
      entityType: entityType,
      operation: operation,
      payload: json.encode(payload),
      status: const Value('PENDING'),
      attempts: const Value(0),
      createdAt: DateTime.now(),
    );
  }

  Future<List<OutboxData>> pendientes() async {
    try {
      return await (_db.select(
        _db.outbox,
      )..orderBy([(t) => OrderingTerm(expression: t.createdAt)])).get();
    } catch (e) {
      AppLogger.error(
        'Error al obtener pendientes de Outbox: $e',
        name: 'OutboxService',
      );
      return []; // Devolver lista vacía para no romper el motor
    }
  }

  Future<List<OutboxData>> itemsConError() async {
    return await (_db.select(_db.outbox)
          ..where((item) => item.status.isIn(['FAILED', 'DEAD']))
          ..orderBy([(item) => OrderingTerm(expression: item.createdAt)]))
        .get();
  }

  Future<void> reintentar(OutboxData item) async {
    await (_db.update(
      _db.outbox,
    )..where((entry) => entry.clientId.equals(item.clientId))).write(
      const OutboxCompanion(
        status: Value('PENDING'),
        attempts: Value(0),
        lastError: Value(null),
      ),
    );
  }

  Future<void> descartar(OutboxData item) async {
    final payload = json.decode(item.payload);
    final localImagePath = payload is Map
        ? payload['local_image_path']?.toString()
        : null;

    if (localImagePath != null && localImagePath.isNotEmpty) {
      try {
        final imageFile = File(localImagePath);
        if (await imageFile.exists()) {
          await imageFile.delete();
        }
      } catch (e) {
        AppLogger.warning(
          'No se pudo limpiar la imagen del item descartado: $e',
          name: 'OutboxService',
        );
      }
    }

    await deleteItem(item.clientId);
  }

  Future<void> updateStatus(
    String clientId,
    String status, {
    String? error,
  }) async {
    // Para simplificar el incremento, lo hacemos en dos pasos o vía custom statement
    // Pero aquí usaremos Value.absent() para status no fallidos y Value(increment) si es necesario.
    // Dado que drift prefiere tipos fuertes, buscaremos el item primero para incrementar.
    if (status == 'FAILED') {
      final item = await (_db.select(
        _db.outbox,
      )..where((t) => t.clientId.equals(clientId))).getSingle();
      await (_db.update(
        _db.outbox,
      )..where((t) => t.clientId.equals(clientId))).write(
        OutboxCompanion(
          status: Value(status),
          lastError: Value(error),
          attempts: Value(item.attempts + 1),
        ),
      );
    } else {
      await (_db.update(
        _db.outbox,
      )..where((t) => t.clientId.equals(clientId))).write(
        OutboxCompanion(status: Value(status), lastError: Value(error)),
      );
    }
  }

  Future<void> deleteItem(String clientId) async {
    await (_db.delete(
      _db.outbox,
    )..where((t) => t.clientId.equals(clientId))).go();
  }
}
