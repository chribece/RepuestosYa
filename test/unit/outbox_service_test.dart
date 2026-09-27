import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repuestosya/database/app_database.dart';
import 'package:repuestosya/services/outbox.dart';

/// OutboxService contra Drift in-memory (Fase 5.3 de docs/TESTING.md): las
/// ramas de `descartar` (con/sin imagen, imagen inexistente), `reintentar` e
/// `itemsConError` que la cobertura marcaba sin recorrer.
void main() {
  late AppDatabase db;
  late OutboxService outbox;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    outbox = OutboxService(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<OutboxData> encolar({Map<String, dynamic>? payload}) async {
    await outbox.enqueue(
      entityType: 'solicitud',
      operation: 'CREATE',
      payload: payload ?? {'pieza_nombre': 'Filtro'},
    );
    return (await outbox.pendientes()).last;
  }

  group('descartar (limpieza de imagen local, R09)', () {
    test('con imagen existente: borra el archivo y elimina el item', () async {
      final dir = await Directory.systemTemp.createTemp('outbox_test');
      addTearDown(() => dir.delete(recursive: true));
      final imagen = File('${dir.path}/foto.jpg');
      await imagen.writeAsBytes([1, 2, 3]);

      final item = await encolar(payload: {'local_image_path': imagen.path});
      expect(await imagen.exists(), isTrue);

      await outbox.descartar(item);

      expect(await imagen.exists(), isFalse);
      expect(await outbox.pendientes(), isEmpty);
    });

    test('sin imagen: solo elimina el item (no toca archivos)', () async {
      final item = await encolar(payload: {'pieza_nombre': 'Filtro'});

      await outbox.descartar(item);

      expect(await outbox.pendientes(), isEmpty);
    });

    test('con imagen inexistente: elimina el item sin lanzar', () async {
      final item = await encolar(
        payload: {'local_image_path': '/no/existe/esta/foto.jpg'},
      );

      await outbox.descartar(item);

      expect(await outbox.pendientes(), isEmpty);
    });
  });

  group('itemsConError / reintentar', () {
    test('itemsConError filtra solo FAILED/DEAD', () async {
      await encolar(); // PENDING
      final fallido = await encolar(payload: {'x': 1});
      await outbox.updateStatus(fallido.clientId, 'FAILED', error: 'boom');

      final conError = await outbox.itemsConError();

      expect(conError, hasLength(1));
      expect(conError.single.clientId, fallido.clientId);
    });

    test('reintentar resetea status, attempts y lastError', () async {
      final item = await encolar();
      await outbox.updateStatus(item.clientId, 'FAILED', error: 'boom');
      await outbox.updateStatus(
        item.clientId,
        'FAILED',
        error: 'boom otra vez',
      );

      await outbox.reintentar(item);

      final reseteado = (await outbox.pendientes()).single;
      expect(reseteado.status, 'PENDING');
      expect(reseteado.attempts, 0);
      expect(reseteado.lastError, isNull);
    });
  });

  group('updateStatus', () {
    test('FAILED incrementa attempts y guarda el error', () async {
      final item = await encolar();

      await outbox.updateStatus(item.clientId, 'FAILED', error: 'e1');
      await outbox.updateStatus(item.clientId, 'FAILED', error: 'e2');

      final actual = (await outbox.pendientes()).single;
      expect(actual.attempts, 2);
      expect(actual.lastError, 'e2');
      expect(actual.status, 'FAILED');
    });

    test('status no-FAILED no incrementa attempts', () async {
      final item = await encolar();

      await outbox.updateStatus(item.clientId, 'SYNCING');

      final actual = (await outbox.pendientes()).single;
      expect(actual.status, 'SYNCING');
      expect(actual.attempts, 0);
    });

    test('FAILED sobre item inexistente: no-op sin lanzar (R10 — logout o '
        'descarte en vuelo del SyncEngine)', () async {
      // El SyncEngine puede llamar updateStatus(FAILED) sobre un item que
      // clearAll()/descartar() ya eliminó (carrera): debe ser un no-op, no
      // un StateError sin capturar.
      await outbox.updateStatus('no-existe', 'FAILED', error: 'boom');

      expect(await outbox.pendientes(), isEmpty);
    });
  });
}
