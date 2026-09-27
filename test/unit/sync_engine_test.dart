import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:repuestosya/database/app_database.dart';
import 'package:repuestosya/services/outbox.dart';
import 'package:repuestosya/services/solicitud_repository.dart';
import 'package:repuestosya/services/sync_engine.dart';
import 'package:repuestosya/utils/api_error_handler.dart';

import '../helpers/fake_services.dart';

/// SyncEngine contra Drift in-memory + doble de [SolicitudService] (Fase 4
/// de docs/TESTING.md): éxito, FAILED→DEAD vs errores de red que nunca
/// agotan, imagen local perdida (R07), cotizaciones e idempotencia estable.
void main() {
  late AppDatabase db;
  late OutboxService outbox;
  late SolicitudRepository repository;
  late FakeSolicitudService servicio;
  late SyncEngine engine;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    outbox = OutboxService(db);
    repository = SolicitudRepository(db);
    servicio = FakeSolicitudService();
    // autoStart: false → sin timers ni listeners de conectividad.
    engine = SyncEngine(
      outbox,
      repository,
      solicitudService: servicio,
      autoStart: false,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> esperarHasta(
    Future<bool> Function() condicion, {
    String? mensaje,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final fin = DateTime.now().add(timeout);
    while (!await condicion()) {
      if (DateTime.now().isAfter(fin)) {
        fail('timeout esperando: ${mensaje ?? 'condición'}');
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  /// Dispara la cola y espera a que TODO el procesamiento termine.
  Future<void> procesarColaEsperando() async {
    await engine.procesarCola();
    await esperarHasta(() async => !engine.procesando, mensaje: 'cola idle');
  }

  Future<OutboxData> unicoItem() async => (await outbox.pendientes()).single;

  Future<String> encolarSolicitud({Map<String, dynamic>? extra}) async {
    return outbox.enqueueSolicitud(
      payload: {
        'cliente_id': 'u-1',
        'vehiculo_id': 'v-1',
        'pieza_nombre': 'Filtro',
        'descripcion': 'ruido',
        'direccion_entrega_id': 'd-1',
        'es_urgente': false,
        'categoria_id': 'cat-1',
        'repuesto_id': 'rep-1',
        'repuesto_nombre_snapshot': 'Filtro de aceite',
        'descripcion_problema': 'ruido al frenar',
        ...?extra,
      },
      localRequest: (clientId) => SolicitudLocal(
        id: clientId,
        clientId: clientId,
        vehiculoId: 'v-1',
        piezaNombre: 'Filtro',
        estado: 'pendiente',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        synced: false,
      ),
    );
  }

  group('flujo de solicitud', () {
    test(
      'éxito: outbox vacío y la local queda synced con el id del servidor',
      () async {
        servicio.respuestaCrear = {
          'id': 'srv-1',
          'pieza_nombre': 'Filtro',
          'estado': 'en_proceso',
        };

        await encolarSolicitud();
        await procesarColaEsperando();

        expect(await outbox.pendientes(), isEmpty);
        final locales = await repository.obtenerLocal();
        expect(locales, hasLength(1));
        expect(locales.single.id, 'srv-1');
        expect(locales.single.synced, isTrue);
        expect(servicio.crearSolicitudCalls, 1);
      },
    );

    test('la idempotency key es estable entre reintentos (R05)', () async {
      // Primer intento: error de negocio.
      servicio.falloAlCrear = const ApiException('x', statusCode: 500);
      await encolarSolicitud();
      await procesarColaEsperando();
      expect(servicio.idempotencyKeysCrear, hasLength(1));

      // Segundo intento: éxito.
      servicio.falloAlCrear = null;
      servicio.respuestaCrear = {'id': 'srv-1'};
      await procesarColaEsperando();

      expect(servicio.crearSolicitudCalls, 2);
      expect(servicio.idempotencyKeysCrear, hasLength(2));
      expect(servicio.idempotencyKeysCrear[0], isNotNull);
      expect(
        servicio.idempotencyKeysCrear[0],
        servicio.idempotencyKeysCrear[1],
      );
    });

    test('error de negocio: FAILED con intentos y DEAD tras 5 (R08)', () async {
      servicio.falloAlCrear = const ApiException(
        '422 del backend',
        statusCode: 422,
      );

      await encolarSolicitud();
      for (var i = 0; i < 5; i++) {
        await procesarColaEsperando();
      }

      final item = await unicoItem();
      expect(item.status, 'DEAD');
      // 5 intentos reales contra el servicio; el campo attempts no se
      // incrementa en la escritura terminal DEAD (comportamiento actual).
      expect(servicio.crearSolicitudCalls, 5);
      expect(item.attempts, 4);
    });

    test(
      'error de red: FAILED y NUNCA DEAD aunque se reintente (R08)',
      () async {
        // Sin statusCode = sin respuesta del servidor = transitorio.
        servicio.falloAlCrear = const ApiException('sin conexión');

        await encolarSolicitud();
        for (var i = 0; i < 6; i++) {
          await procesarColaEsperando();
        }

        final item = await unicoItem();
        expect(item.status, 'FAILED'); // nunca DEAD
        expect(item.attempts, 6);
      },
    );

    test('imagen local perdida: FAILED con error claro (R07)', () async {
      await encolarSolicitud(extra: {'local_image_path': '/no/existe.jpg'});
      await procesarColaEsperando();

      final item = await unicoItem();
      expect(item.status, 'FAILED');
      expect(item.lastError, contains('imagen local no encontrada'));
      // No es error de red → cuenta para DEAD.
      expect(item.attempts, 1);
    });
  });

  group('flujo de cotización', () {
    Future<void> encolarCotizacion({Map<String, dynamic>? payload}) async {
      await outbox.enqueueCotizacion(
        payload:
            payload ??
            {
              'solicitud_id': 's-1',
              'almacen_id': 'a-1',
              'precio': 25.5,
              'notas': 'con garantía',
              'tiempo_entrega_estimado': '2 días',
              'condicion_repuesto': 'nuevo',
            },
        localQuotation: (clientId) => CotizacionPendiente(
          id: clientId,
          clientId: clientId,
          solicitudId: 's-1',
          almacenId: 'a-1',
          precio: 25.5,
          tiempoEntrega: '2 días',
          estado: 'pendiente',
          synced: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    }

    test('éxito: pendiente borrada, outbox vacío y key estable', () async {
      await encolarCotizacion();
      await procesarColaEsperando();

      expect(await outbox.pendientes(), isEmpty);
      expect(await db.select(db.cotizacionesPendientes).get(), isEmpty);
      expect(servicio.crearCotizacionCalls, 1);
      expect(servicio.idempotencyKeysCotizacion.single, isNotNull);
    });

    test('precio como string (numeric de Postgres): se sincroniza igual '
        '(R06 — cast endurecido)', () async {
      await encolarCotizacion(
        payload: {
          'solicitud_id': 's-1',
          'almacen_id': 'a-1',
          'precio': '25.5', // llega como string
          'tiempo_entrega_estimado': '2 días',
        },
      );
      await procesarColaEsperando();

      // El TypeError del cast `as num` NO debe condenar la cotización.
      expect(await outbox.pendientes(), isEmpty);
      expect(servicio.crearCotizacionCalls, 1);
    });
  });
}
