import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:repuestosya/database/app_database.dart';
import 'package:repuestosya/pages/mis_ordenes_page.dart';
import 'package:repuestosya/pages/todas_solicitudes_page.dart';
import 'package:repuestosya/pages/warehouse_dashboard.dart';
import 'package:repuestosya/providers/solicitudes_provider.dart';
import 'package:repuestosya/router/route_names.dart';
import 'package:repuestosya/services/auth_service.dart';
import 'package:repuestosya/services/outbox.dart';
import 'package:repuestosya/services/solicitud_repository.dart';
import 'package:repuestosya/services/sync_engine.dart';
import 'package:repuestosya/utils/api_error_handler.dart';
import 'package:repuestosya/widgets/ry_part_card.dart';

import '../helpers/fake_connectivity.dart';
import '../helpers/fake_services.dart';
import '../helpers/fake_solicitud_repository.dart';

/// Swipe (flutter_slidable) en las listas de la fase: verifica que el control
/// visible alternativo de cada lista (tap de la tarjeta / botón "Ver
/// Detalles") sigue funcionando SIN el gesto, dentro del [Slidable] — regla
/// de accesibilidad: ninguna acción queda solo detrás del swipe.
///
/// Las acciones destructivas (eliminar/cancelar solicitud, cancelar orden,
/// retirar cotización) NO se implementaron: no existe endpoint en el backend
/// (Paso 0 de la fase) — ver informe.
/// Página placeholder para verificar que la navegación del tap/botón
/// realmente ocurre dentro del router de prueba.
class _PaginaDetalle extends StatelessWidget {
  const _PaginaDetalle(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(texto)));
  }
}

void main() {
  late FakeConnectivityPlatform conectividad;

  setUp(() {
    conectividad = FakeConnectivityPlatform();
    ConnectivityPlatform.instance = conectividad;
    // El singleton de Auth no arrastra sesión entre tests.
    AuthService().currentUserForTesting = null;
  });

  testWidgets(
    'todas_solicitudes: el tap de la tarjeta (alternativa visible) navega '
    'aunque la tarjeta esté envuelta en Slidable',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final fake = FakeSolicitudRepository()..setOnline(true);
      fake.setRespuestaServidor([
        {
          'id': 'srv-1',
          'pieza_nombre': 'Filtro de aceite',
          'estado': 'pendiente',
          'created_at': '2026-09-20T10:00:00.000Z',
        },
      ]);

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final outbox = OutboxService(db);
      final repository = SolicitudRepository(db);
      final engine = SyncEngine(outbox, repository, autoStart: false);

      final provider = SolicitudesProvider(fake);
      addTearDown(provider.dispose);

      final router = GoRouter(
        initialLocation: '/solicitudes',
        routes: [
          GoRoute(
            path: '/solicitudes',
            builder: (_, _) => const TodasSolicitudesPage(),
          ),
          GoRoute(
            path: '/solicitudes/:id',
            name: RouteNames.receivedQuotations,
            builder: (_, _) => const _PaginaDetalle('Cotizaciones OK'),
          ),
        ],
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<SolicitudesProvider>.value(
          value: provider,
          child: MultiProvider(
            providers: [
              Provider<OutboxService>.value(value: outbox),
              Provider<SyncEngine>.value(value: engine),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // La lista renderiza la tarjeta sincronizada envuelta en Slidable.
      expect(find.byType(RyPartCard), findsOneWidget);
      expect(find.byType(Slidable), findsOneWidget);

      // Alternativa visible sin gesto: el tap de la tarjeta sigue funcionando
      // dentro del Slidable y navega al detalle (misma ruta que el swipe).
      await tester.tap(find.byType(RyPartCard));
      await tester.pumpAndSettle();

      expect(find.text('Cotizaciones OK'), findsOneWidget);
    },
  );

  testWidgets(
    'mis_ordenes: el botón visible "Ver Detalles" navega aunque la tarjeta '
    'esté envuelta en Slidable',
    (tester) async {
      AuthService().currentUserForTesting = User(
        id: 'u-1',
        email: 'cliente@test.com',
        rol: 'cliente',
      );
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final servicio = FakeSolicitudService()
        ..respuestaMisOrdenes = [
          {
            'id': 'o-1',
            'estado': 'pendiente',
            'created_at': '2026-09-20T10:00:00.000Z',
            'cotizaciones': {
              'precio_venta': '25.50',
              'almacenes': {'nombre_comercial': 'Repuestos Central'},
            },
            'solicitudes_repuesto': {
              'repuesto_nombre_snapshot': 'Filtro de aceite',
            },
          },
        ];

      final router = GoRouter(
        initialLocation: '/mis-ordenes',
        routes: [
          GoRoute(
            path: '/mis-ordenes',
            builder: (_, _) => MisOrdenesPage(solicitudService: servicio),
          ),
          GoRoute(
            path: '/orden/:id',
            name: RouteNames.ordenDetalle,
            builder: (_, _) => const _PaginaDetalle('Orden OK'),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // La orden renderiza su tarjeta envuelta en Slidable.
      expect(find.text('Filtro de aceite'), findsOneWidget);
      expect(find.byType(Slidable), findsOneWidget);

      // Alternativa visible sin gesto: el botón "Ver Detalles" navega.
      await tester.tap(find.text('Ver Detalles'));
      await tester.pumpAndSettle();

      expect(find.text('Orden OK'), findsOneWidget);
    },
  );

  testWidgets(
    'warehouse_dashboard "mis cotizaciones": el tap de la tarjeta aceptada '
    'con orden (alternativa visible) navega dentro del Slidable',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'rationale_notificaciones': true,
      });
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final almacen = FakeAlmacenService()
        ..respuestaMiAlmacen = {
          'id': 'a-1',
          'nombre_comercial': 'Repuestos Central',
          'verification_status': 'approved',
          'estado_abierto': true,
        };
      final solicitud = FakeSolicitudService()
        ..respuestaMisCotizaciones = [
          {
            'id': 'cot-1',
            'precio_venta': 25.50,
            'estado': 'aceptada',
            'created_at': '2026-09-20T10:00:00.000Z',
            'tiempo_entrega_estimado': '24-48 horas',
            'solicitudes_repuesto': {
              'pieza_nombre': 'Filtro de aceite',
              'profiles': {'nombre_completo': 'Juan Pérez'},
            },
            'ordenes_compra': {'id': 'ord-1', 'estado': 'pendiente_pago'},
          },
        ];

      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, _) => WarehouseDashboard(
              almacenService: almacen,
              solicitudService: solicitud,
            ),
          ),
          GoRoute(
            path: '/dashboard/orden/:id',
            name: RouteNames.ordenDetalleAlmacen,
            builder: (_, _) => const _PaginaDetalle('Orden Almacén OK'),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Ir a la sección "Cotizaciones Enviadas" (bottom nav index 2).
      await tester.tap(find.text('Cotizaciones'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // La cotización aceptada con orden renderiza su tarjeta en Slidable.
      expect(find.text('Filtro de aceite'), findsOneWidget);
      expect(find.byType(Slidable), findsOneWidget);

      // Alternativa visible sin gesto: el tap de la tarjeta navega a la orden.
      await tester.tap(find.text('Filtro de aceite'));
      await tester.pumpAndSettle();

      expect(find.text('Orden Almacén OK'), findsOneWidget);
    },
  );

  testWidgets(
    'warehouse_dashboard "mis cotizaciones": una cotización PENDIENTE '
    'no lleva Slidable (sin orden no hay destino de detalle)',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'rationale_notificaciones': true,
      });
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final almacen = FakeAlmacenService()
        ..respuestaMiAlmacen = {
          'id': 'a-1',
          'nombre_comercial': 'Repuestos Central',
          'verification_status': 'approved',
          'estado_abierto': true,
        };
      final solicitud = FakeSolicitudService()
        ..respuestaMisCotizaciones = [
          {
            'id': 'cot-pend',
            'precio_venta': 25.50,
            'estado': 'pendiente',
            'created_at': '2026-09-20T10:00:00.000Z',
            'tiempo_entrega_estimado': '24-48 horas',
            'solicitudes_repuesto': {
              'pieza_nombre': 'Filtro de aceite',
              'profiles': {'nombre_completo': 'Juan Pérez'},
            },
            'ordenes_compra': null,
          },
        ];

      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, _) => WarehouseDashboard(
              almacenService: almacen,
              solicitudService: solicitud,
            ),
          ),
          GoRoute(
            path: '/dashboard/orden/:id',
            name: RouteNames.ordenDetalleAlmacen,
            builder: (_, _) => const _PaginaDetalle('Orden Almacén OK'),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Ir a la sección "Cotizaciones Enviadas" (bottom nav index 2).
      await tester.tap(find.text('Cotizaciones'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // La cotización pendiente se muestra SIN swipe: la condición del
      // Slidable (aceptada && ordenId != null) no debe regresar nunca.
      expect(find.text('Filtro de aceite'), findsOneWidget);
      expect(find.byType(Slidable), findsNothing);
    },
  );

  testWidgets(
    'warehouse_dashboard "mis cotizaciones": la pestaña Ganadas muestra la '
    'cotización aceptada con orden recién creada (estado pendiente) y su '
    'Slidable — regresión del filtro que la ocultaba',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'rationale_notificaciones': true,
      });
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final almacen = FakeAlmacenService()
        ..respuestaMiAlmacen = {
          'id': 'a-1',
          'nombre_comercial': 'Repuestos Central',
          'verification_status': 'approved',
          'estado_abierto': true,
        };
      final solicitud = FakeSolicitudService()
        ..respuestaMisCotizaciones = [
          {
            'id': 'cot-ganada',
            'precio_venta': 25.50,
            'estado': 'aceptada',
            'created_at': '2026-09-20T10:00:00.000Z',
            'tiempo_entrega_estimado': '24-48 horas',
            'solicitudes_repuesto': {
              'pieza_nombre': 'Filtro de aceite',
              'profiles': {'nombre_completo': 'Juan Pérez'},
            },
            // Estado real con el que el RPC aceptar_cotizacion crea la orden.
            'ordenes_compra': {'id': 'ord-pend', 'estado': 'pendiente'},
          },
        ];

      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, _) => WarehouseDashboard(
              almacenService: almacen,
              solicitudService: solicitud,
            ),
          ),
          GoRoute(
            path: '/dashboard/orden/:id',
            name: RouteNames.ordenDetalleAlmacen,
            builder: (_, _) => const _PaginaDetalle('Orden Almacén OK'),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Ir a la sección "Cotizaciones Enviadas" y activar la pestaña Ganadas.
      await tester.tap(find.text('Cotizaciones'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Ganadas'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // La cotización aceptada con orden 'pendiente' SÍ aparece en Ganadas
      // (antes del fix el filtro la ocultaba) y lleva su Slidable.
      expect(find.text('Filtro de aceite'), findsOneWidget);
      expect(find.byType(Slidable), findsOneWidget);
    },
  );

  // ---------------------------------------------------------------------------
  // PARTE 2 — Swipes Lado A/B en "Mis Solicitudes" del cliente
  // ---------------------------------------------------------------------------

  /// Monta TodasSolicitudesPage con un provider alimentado por el repositorio
  /// falso y un SolicitudService falso (cancelación scriptable). El refresh
  /// post-frame devuelve [servidor] para poblar la lista con items synced.
  Future<SolicitudesProvider> pumpTodasSolicitudes(
    WidgetTester tester, {
    required FakeSolicitudRepository fake,
    required FakeSolicitudService servicio,
    List<Map<String, dynamic>> servidor = const [],
    bool online = true,
  }) async {
    fake.setOnline(online);
    fake.setRespuestaServidor(servidor);
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final outbox = OutboxService(db);
    final repository = SolicitudRepository(db);
    final engine = SyncEngine(outbox, repository, autoStart: false);
    final provider = SolicitudesProvider(fake);
    addTearDown(provider.dispose);

    final router = GoRouter(
      initialLocation: '/solicitudes',
      routes: [
        GoRoute(
          path: '/solicitudes',
          builder: (_, _) => TodasSolicitudesPage(solicitudService: servicio),
        ),
        GoRoute(
          path: '/solicitudes/:id',
          name: RouteNames.receivedQuotations,
          builder: (_, _) => const _PaginaDetalle('Cotizaciones OK'),
        ),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<SolicitudesProvider>.value(
        value: provider,
        child: MultiProvider(
          providers: [
            Provider<OutboxService>.value(value: outbox),
            Provider<SyncEngine>.value(value: engine),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    return provider;
  }

  testWidgets(
    'todas_solicitudes: swipe a la IZQUIERDA revela "Detalle" (endActionPane) '
    'y navega; swipe a la DERECHA revela "Cancelar" (startActionPane)',
    (tester) async {
      final fake = FakeSolicitudRepository();
      final servicio = FakeSolicitudService();
      await pumpTodasSolicitudes(
        tester,
        fake: fake,
        servicio: servicio,
        servidor: [
          {
            'id': 'srv-1',
            'pieza_nombre': 'Filtro de aceite',
            'estado': 'en_proceso',
            'created_at': '2026-09-20T10:00:00.000Z',
          },
        ],
      );

      // La tarjeta sincronizada activa lleva AMBOS paneles: Detalle (derecha)
      // y Cancelar (izquierda).
      expect(find.byType(RyPartCard), findsOneWidget);
      final slidable = tester.widget<Slidable>(find.byType(Slidable));
      expect(slidable.endActionPane, isNotNull);
      expect(slidable.startActionPane, isNotNull);

      // Gesto A: deslizar a la IZQUIERDA (contenido se corre a la izquierda →
      // panel derecho) revela "Detalle" y navega a las cotizaciones recibidas.
      await tester.drag(find.byType(Slidable), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text('Detalle'), findsOneWidget);
      await tester.tap(find.text('Detalle'));
      await tester.pumpAndSettle();
      expect(find.text('Cotizaciones OK'), findsOneWidget);
    },
  );

  testWidgets(
    'todas_solicitudes: swipe a la DERECHA revela "Cancelar" (startActionPane) '
    'y abre la confirmación obligatoria antes de cancelar',
    (tester) async {
      final fake = FakeSolicitudRepository();
      final servicio = FakeSolicitudService();
      await pumpTodasSolicitudes(
        tester,
        fake: fake,
        servicio: servicio,
        servidor: [
          {
            'id': 'srv-1',
            'pieza_nombre': 'Filtro de aceite',
            'estado': 'en_proceso',
            'created_at': '2026-09-20T10:00:00.000Z',
          },
        ],
      );

      // Gesto B: deslizar a la DERECHA (contenido se corre a la derecha →
      // panel izquierdo) revela "Cancelar".
      await tester.drag(find.byType(Slidable), const Offset(400, 0));
      await tester.pumpAndSettle();
      expect(find.text('Cancelar'), findsOneWidget);

      // Confirmación obligatoria: el gesto no cancela directo.
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Confirmar'), findsOneWidget);

      // Al responder "No" NO se llama al servicio.
      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();
      expect(find.text('Confirmar'), findsNothing);
      expect(servicio.cancelarSolicitudCalls, 0);
    },
  );

  testWidgets(
    'todas_solicitudes: una solicitud ya respondida (asignada) no ofrece '
    'Cancelar (sin startActionPane) ni menú "⋮"',
    (tester) async {
      final fake = FakeSolicitudRepository();
      final servicio = FakeSolicitudService();
      await pumpTodasSolicitudes(
        tester,
        fake: fake,
        servicio: servicio,
        servidor: [
          {
            'id': 'srv-1',
            'pieza_nombre': 'Filtro de aceite',
            'estado': 'asignada',
            'created_at': '2026-09-20T10:00:00.000Z',
          },
        ],
      );

      expect(find.byType(RyPartCard), findsOneWidget);
      final slidable = tester.widget<Slidable>(find.byType(Slidable));
      // Detalle sigue disponible (swipe izquierda)…
      expect(slidable.endActionPane, isNotNull);
      // …pero Cancelar no (el servidor ya la respondió).
      expect(slidable.startActionPane, isNull);
      // Sin control visible de cancelar para este estado.
      expect(find.byIcon(Icons.more_vert), findsNothing);
    },
  );

  testWidgets(
    'todas_solicitudes: sin conexión no se ofrece Cancelar por gesto y el '
    'menú "⋮" avisa que se necesita conexión (no se encola en Outbox)',
    (tester) async {
      final fake = FakeSolicitudRepository();
      final servicio = FakeSolicitudService();
      await pumpTodasSolicitudes(
        tester,
        fake: fake,
        servicio: servicio,
        online: false,
        servidor: [
          {
            'id': 'srv-1',
            'pieza_nombre': 'Filtro de aceite',
            'estado': 'en_proceso',
            'created_at': '2026-09-20T10:00:00.000Z',
          },
        ],
      );

      // Sin conexión el refresh no trae datos del servidor: la tarjeta sale
      // de la caché local (se emite directamente al stream del repositorio
      // falso, como haría Drift con datos persistidos).
      fake.emiteSolicitudes([
        SolicitudLocal(
          id: 'srv-1',
          vehiculoId: 'v1',
          piezaNombre: 'Filtro de aceite',
          estado: 'en_proceso',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          synced: true,
        ),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(RyPartCard), findsOneWidget);
      final slidable = tester.widget<Slidable>(find.byType(Slidable));
      // Detalle sí (sin red el detalle de datos locales sigue siendo válido)…
      expect(slidable.endActionPane, isNotNull);
      // …pero Cancelar NO: la cancelación la debe validar el servidor.
      expect(slidable.startActionPane, isNull);

      // Alternativa visible: el menú "⋮" está y avisa que se necesita
      // conexión en lugar de intentar cancelar.
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar solicitud'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Necesitas conexión para cancelar la solicitud.'),
        findsOneWidget,
      );
      expect(servicio.cancelarSolicitudCalls, 0);
    },
  );

  testWidgets(
    'todas_solicitudes: cancelar con éxito llama al servicio, muestra '
    'confirmación y refresca la lista',
    (tester) async {
      final fake = FakeSolicitudRepository();
      final servicio = FakeSolicitudService();
      await pumpTodasSolicitudes(
        tester,
        fake: fake,
        servicio: servicio,
        servidor: [
          {
            'id': 'srv-1',
            'pieza_nombre': 'Filtro de aceite',
            'estado': 'en_proceso',
            'created_at': '2026-09-20T10:00:00.000Z',
          },
        ],
      );
      final llamadasAntes = fake.llamadasObtener;

      await tester.drag(find.byType(Slidable), const Offset(400, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, cancelar'));
      await tester.pumpAndSettle();

      expect(servicio.cancelarSolicitudCalls, 1);
      expect(servicio.ultimaSolicitudCancelada, 'srv-1');
      expect(find.text('Solicitud cancelada'), findsOneWidget);
      // Refresco post-cancelación: la lista se vuelve a pedir al servidor.
      expect(fake.llamadasObtener, greaterThan(llamadasAntes));
    },
  );

  testWidgets(
    'todas_solicitudes: el servidor rechaza la cancelación (409 ya respondida) '
    '→ muestra el mensaje del servidor y refresca la lista',
    (tester) async {
      final fake = FakeSolicitudRepository();
      final servicio = FakeSolicitudService()
        ..falloAlCancelar = const ApiException(
          'La solicitud ya fue respondida por un almacén',
          statusCode: 409,
          type: ApiErrorType.http,
        );
      await pumpTodasSolicitudes(
        tester,
        fake: fake,
        servicio: servicio,
        servidor: [
          {
            'id': 'srv-1',
            'pieza_nombre': 'Filtro de aceite',
            'estado': 'en_proceso',
            'created_at': '2026-09-20T10:00:00.000Z',
          },
        ],
      );
      final llamadasAntes = fake.llamadasObtener;

      await tester.drag(find.byType(Slidable), const Offset(400, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, cancelar'));
      await tester.pumpAndSettle();

      // Mensaje legible del servidor, no un error genérico.
      expect(
        find.text('La solicitud ya fue respondida por un almacén'),
        findsOneWidget,
      );
      // Refresco para reflejar el estado real de la solicitud.
      expect(fake.llamadasObtener, greaterThan(llamadasAntes));
    },
  );
}
