import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../utils/app_logger.dart';

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
    final entry = OutboxCompanion.insert(
      clientId: clientId,
      entityType: entityType,
      operation: operation,
      payload: json.encode(payload),
      status: const Value('PENDING'),
      attempts: const Value(0),
      createdAt: DateTime.now(),
    );

    await _db.into(_db.outbox).insert(entry);
    return clientId;
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
