import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:repuestosya/pages/home_page.dart';
import 'package:repuestosya/providers/create_request_provider.dart';
import 'package:repuestosya/providers/solicitudes_provider.dart';
import 'package:repuestosya/services/auth_service.dart';
import 'package:repuestosya/utils/api_error_handler.dart';
import 'package:repuestosya/widgets/ry_part_card.dart';

import '../helpers/fake_connectivity.dart';
import '../helpers/fake_services.dart';
import '../helpers/fake_solicitud_repository.dart';

/// Los 4 estados de la sección "Mis Solicitudes" del Home del cliente
/// (Fase 2 de docs/TESTING.md): cargando / con datos / vacía / error.
///
/// La fuente de datos es el [FakeSolicitudRepository] reutilizable (Fase 4),
/// inyectado vía [SolicitudesProvider]; el transporte HTTP nunca se toca.
void main() {
  late FakeConnectivityPlatform conectividad;

  setUp(() {
    conectividad = FakeConnectivityPlatform();
    ConnectivityPlatform.instance = conectividad;
    // Garantiza que el singleton de Auth no arrastre sesión entre tests.
    AuthService().currentUserForTesting = null;
  });

  Future<SolicitudesProvider> pumpHome(
    WidgetTester tester,
    FakeSolicitudRepository fake, {
    Size size = const Size(800, 2000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final provider = SolicitudesProvider(fake);
    final createRequestProvider = CreateRequestProvider();
    addTearDown(createRequestProvider.dispose);
    addTearDown(provider.dispose);
    final catalogService = FakeCatalogService()
      ..respuestaCategorias = categoriasRepuestosDePrueba();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SolicitudesProvider>.value(value: provider),
          ChangeNotifierProvider<CreateRequestProvider>.value(
            value: createRequestProvider,
          ),
        ],
        child: MaterialApp(home: HomePage(catalogService: catalogService)),
      ),
    );
    // Primer frame + post-frame del Home (dispara refreshFromServer).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return provider;
  }

  testWidgets('estado CARGANDO: spinner y título, sin contenido final', (
    tester,
  ) async {
    final fake = FakeSolicitudRepository()..setOnline(true);
    // La respuesta del "servidor" nunca llega → isLoading permanece true.
    fake.bloquearRespuesta();
    await pumpHome(tester, fake);

    expect(find.text('Cargando solicitudes...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    // El contenido final (tarjetas / estado vacío) NO debe renderizarse.
    expect(find.text('Sin solicitudes'), findsNothing);
    expect(find.byType(RyPartCard), findsNothing);
  });

  testWidgets('estado CON DATOS: las tarjetas renderizan los datos reales', (
    tester,
  ) async {
    final fake = FakeSolicitudRepository()..setOnline(true);
    fake.setRespuestaServidor([
      {
        'id': 'srv-1',
        'pieza_nombre': 'Filtro de aceite',
        'estado': 'pendiente',
        'created_at': '2026-09-20T10:00:00.000Z',
      },
      {
        'id': 'srv-2',
        'pieza_nombre': 'Bujías NGK',
        'estado': 'en_proceso',
        'created_at': '2026-09-21T10:00:00.000Z',
      },
    ]);
    final provider = await pumpHome(tester, fake);

    // El provider recibió los datos del "servidor" y la UI los muestra.
    expect(provider.solicitudes, hasLength(2));
    expect(find.text('Filtro de aceite'), findsOneWidget);
    expect(find.text('Bujías NGK'), findsOneWidget);
    // Con datos no se muestra ni loading ni vacío.
    expect(find.text('Cargando solicitudes...'), findsNothing);
    expect(find.text('Sin solicitudes'), findsNothing);

    // La métrica activa muestra el total calculado desde las solicitudes.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('stat-card-Solicitudes Activas')),
        matching: find.text('02'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('estado VACÍA: mensaje real de estado vacío con CTA', (
    tester,
  ) async {
    final fake = FakeSolicitudRepository()..setOnline(true);
    fake.setRespuestaServidor([]);
    await pumpHome(tester, fake);

    expect(find.text('Sin solicitudes'), findsOneWidget);
    expect(find.text('Crea tu primera solicitud de repuesto'), findsOneWidget);
    expect(find.byType(RyPartCard), findsNothing);
  });

  testWidgets(
    'estado ERROR: la sincronización falla → banner de datos desactualizados '
    'con reintento (la pantalla no expone error en crudo, riesgo R15)',
    (tester) async {
      final fake = FakeSolicitudRepository()
        ..setOnline(true)
        ..setUltimaSincronizacion(
          DateTime.now().subtract(const Duration(minutes: 11)),
        );
      // El backend falla (500): el provider traga el error (R15).
      fake.setFalloAlObtener(
        ApiErrorHandler.fromResponse(
          http.Response('{"error":"internal"}', 500),
        ),
      );
      final provider = await pumpHome(tester, fake);

      // No hay estado de error dedicado: queda el vacío + banner con CTA.
      expect(fake.llamadasObtener, 1);
      expect(provider.isLoading, isFalse);
      expect(find.text('Datos desactualizados'), findsOneWidget);
      expect(find.text('SINCRONIZAR'), findsOneWidget);

      // El CTA del banner es la acción de reintento real.
      await tester.tap(find.text('SINCRONIZAR'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(fake.llamadasObtener, greaterThanOrEqualTo(2));
    },
  );

  testWidgets(
    'banner sin conexión: tocarlo reintenta y se oculta al volver la red',
    (tester) async {
      final fake = FakeSolicitudRepository()
        ..setOnline(false)
        ..setUltimaSincronizacion(DateTime.now());
      final provider = await pumpHome(tester, fake);
      expect(provider.isOffline, isTrue);
      expect(find.text('REINTENTAR'), findsOneWidget);

      final llamadasAntes = fake.llamadasObtener;
      fake.setOnline(true);
      await tester.tap(find.text('Modo sin conexión'));
      await tester.pumpAndSettle();

      expect(fake.llamadasObtener, greaterThan(llamadasAntes));
      expect(provider.isOffline, isFalse);
      expect(find.text('Modo sin conexión'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'al volver al primer plano verifica la red y quita el banner sin tocar '
    'nada',
    (tester) async {
      final fake = FakeSolicitudRepository()
        ..setOnline(false)
        ..setUltimaSincronizacion(DateTime.now());
      final provider = await pumpHome(tester, fake);
      expect(provider.isOffline, isTrue);

      fake.setOnline(true);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(provider.isOffline, isFalse);
      expect(find.text('Modo sin conexión'), findsNothing);
    },
  );

  testWidgets(
    'sin evento nativo, el sondeo detecta el corte: banner sin SnackBar',
    (tester) async {
      final fake = FakeSolicitudRepository()
        ..setOnline(true)
        ..setUltimaSincronizacion(DateTime.now());
      final provider = await pumpHome(tester, fake);
      expect(provider.isOffline, isFalse);

      fake.setOnline(false);
      await tester.pump(const Duration(seconds: 11));
      await tester.pump();

      expect(provider.isOffline, isTrue);
      expect(find.text('Modo sin conexión'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'al recuperar la red el banner muestra "Conexión recuperada" 3 s y luego '
    'desaparece, sin SnackBar',
    (tester) async {
      final fake = FakeSolicitudRepository()
        ..setOnline(false)
        ..setUltimaSincronizacion(DateTime.now());
      final provider = await pumpHome(tester, fake);

      await tester.pump(const Duration(seconds: 11));
      await tester.pump();
      expect(provider.isOffline, isTrue);

      fake.setOnline(true);
      await tester.pump(const Duration(seconds: 11));
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Conexión recuperada. Actualizando...'), findsOneWidget);
      expect(find.text('Modo sin conexión'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Conexión recuperada. Actualizando...'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pull-to-refresh vuelve a pedir las solicitudes', (tester) async {
    final fake = FakeSolicitudRepository()
      ..setOnline(true)
      ..setUltimaSincronizacion(DateTime.now());
    await pumpHome(tester, fake);

    final llamadasAntes = fake.llamadasObtener;
    await tester.drag(
      find.byKey(const ValueKey('home-main-scroll')),
      const Offset(0, 300),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(fake.llamadasObtener, greaterThan(llamadasAntes));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'banner y RefreshIndicator quedan contenidos en pantalla compacta',
    (tester) async {
      final fake = FakeSolicitudRepository()
        ..setOnline(false)
        ..setUltimaSincronizacion(DateTime.now());
      await pumpHome(tester, fake, size: const Size(420, 800));

      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(
        tester.getRect(find.text('Modo sin conexión')).right,
        lessThanOrEqualTo(420),
      );
      expect(
        tester.getRect(find.text('REINTENTAR')).right,
        lessThanOrEqualTo(420),
      );

      // El header "Mis Solicitudes" desborda solo con la fuente Ahem de test
      // (ver home_page_responsive_test.dart); cualquier otra excepción falla.
      final errores = <Object>[];
      for (
        var e = tester.takeException();
        e != null;
        e = tester.takeException()
      ) {
        errores.add(e);
      }
      expect(
        errores.every((e) => e.toString().contains('RenderFlex overflowed')),
        isTrue,
        reason: errores.join('\n'),
      );
    },
  );
}
