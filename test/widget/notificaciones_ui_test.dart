import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:repuestosya/models/notificacion.dart';
import 'package:repuestosya/pages/notificaciones_page.dart';
import 'package:repuestosya/pages/mis_ordenes_page.dart';
import 'package:repuestosya/pages/profile_page.dart';
import 'package:repuestosya/providers/notificaciones_provider.dart';
import 'package:repuestosya/router/route_names.dart';
import 'package:repuestosya/services/auth_service.dart';
import 'package:repuestosya/services/notificaciones_api_service.dart';
import 'package:repuestosya/theme/app_theme.dart';
import 'package:repuestosya/widgets/ry_notification_bell.dart';

import '../helpers/fake_services.dart';

void main() {
  setUp(() {
    AuthService().currentUserForTesting = User(id: 'user-1', email: 'u@test');
  });

  tearDown(() {
    AuthService().currentUserForTesting = null;
  });

  Future<NotificacionesProvider> createProvider(
    WidgetTester tester,
    _FakeNotificacionesApi service,
  ) async {
    final provider = NotificacionesProvider(
      service: service,
      escucharRealtime: false,
    )..initialize();
    addTearDown(provider.dispose);
    await tester.pump();
    await tester.pump();
    return provider;
  }

  Future<void> pumpBell(
    WidgetTester tester,
    NotificacionesProvider provider, {
    VoidCallback? onPressed,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<NotificacionesProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: darkTheme,
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Home'),
              actions: [
                RyNotificationBell(
                  onPressed: onPressed == null ? null : () async => onPressed(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('campana sin badge con cero no leídas y semantics legible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final provider = await createProvider(
      tester,
      _FakeNotificacionesApi(unreadCount: 0),
    );
    await pumpBell(tester, provider);

    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    expect(find.text('0'), findsNothing);
    final semantics = tester.getSemantics(find.byType(RyNotificationBell));
    expect(semantics.label, 'Notificaciones');
    expect(tester.getSize(find.byType(RyNotificationBell)).height, 48);
  });

  testWidgets('campana muestra 9+ y semantics conserva el conteo real', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final provider = await createProvider(
      tester,
      _FakeNotificacionesApi(unreadCount: 12),
    );
    await pumpBell(tester, provider);

    expect(find.text('9+'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(RyNotificationBell)).label,
      '12 notificaciones sin leer',
    );
  });

  testWidgets('campana navega a la lista y refresca al volver', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final service = _FakeNotificacionesApi(unreadCount: 1);
    final provider = await createProvider(tester, service);
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) =>
              Scaffold(appBar: AppBar(actions: [RyNotificationBell()])),
        ),
        GoRoute(
          path: '/notificaciones',
          name: RouteNames.notifications,
          builder: (context, state) => const NotificacionesPage(),
        ),
      ],
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<NotificacionesProvider>.value(
        value: provider,
        child: MaterialApp.router(theme: darkTheme, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(RyNotificationBell));
    await tester.pumpAndSettle();
    expect(find.text('No tienes notificaciones'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(service.unreadCalls, greaterThanOrEqualTo(2));
  });

  testWidgets('tap en cotización recibida abre el detalle de su solicitud', (
    tester,
  ) async {
    final service = _FakeNotificacionesApi(
      unreadCount: 1,
      items: [_item('n-1')],
    );
    final provider = await createProvider(tester, service);
    final router = GoRouter(
      initialLocation: '/notificaciones',
      routes: [
        GoRoute(
          path: '/notificaciones',
          name: RouteNames.notifications,
          builder: (context, state) => const NotificacionesPage(),
        ),
        GoRoute(
          path: '/solicitudes/:id',
          name: RouteNames.receivedQuotations,
          builder: (context, state) => Scaffold(
            body: Center(
              child: Text('Detalle de solicitud ${state.pathParameters['id']}'),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<NotificacionesProvider>.value(
        value: provider,
        child: MaterialApp.router(theme: darkTheme, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nueva cotización'));
    await tester.pumpAndSettle();

    expect(find.text('Detalle de solicitud solicitud-1'), findsOneWidget);
    expect(provider.unreadCount, 0);
    expect(service.marcarLeidaCalls, 1);
  });

  testWidgets('campana cabe en AppBars de Órdenes y Perfil a 420/800px', (
    tester,
  ) async {
    AuthService().currentUserForTesting = null;
    addTearDown(() => AuthService().currentUserForTesting = null);
    final layoutErrors = <FlutterErrorDetails>[];
    final originalFlutterErrorHandler = FlutterError.onError;
    FlutterError.onError = layoutErrors.add;

    try {
      for (final size in [const Size(420, 900), const Size(800, 1200)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;

        await tester.pumpWidget(
          MaterialApp(
            theme: darkTheme,
            home: MisOrdenesPage(solicitudService: FakeSolicitudService()),
          ),
        );
        await tester.pumpAndSettle();
        _expectBellContained(tester, find.byType(AppBar), size.width);
        await tester.pumpWidget(const SizedBox.shrink());

        await tester.pumpWidget(
          MaterialApp(theme: darkTheme, home: const ProfilePage()),
        );
        await tester.pumpAndSettle();
        _expectBellContained(
          tester,
          find.byKey(const ValueKey('profile-top-app-bar')),
          size.width,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    } finally {
      FlutterError.onError = originalFlutterErrorHandler;
    }
    addTearDown(tester.view.reset);
    expect(
      layoutErrors
          .map((error) => error.exceptionAsString())
          .where((error) => error.contains('overflowed')),
      isEmpty,
      reason:
          'El AppBar no debe desbordar a 420/800px:\n'
          '${layoutErrors.map((error) => error.exceptionAsString()).join('\n')}',
    );
  });

  testWidgets('marcar leída baja el badge de inmediato y guarda el cambio', (
    tester,
  ) async {
    final service = _FakeNotificacionesApi(
      unreadCount: 1,
      items: [_item('n-1')],
    )..marcarLeidaCompleter = Completer<DateTime?>();
    final provider = await createProvider(tester, service);
    await provider.cargarInicial();

    final pending = provider.marcarLeida('n-1');
    expect(provider.unreadCount, 0);
    expect(provider.items.single.estaLeida, isTrue);

    service.marcarLeidaCompleter!.complete(DateTime.utc(2026, 10, 17));
    await pending;
    expect(service.marcarLeidaCalls, 1);
  });

  testWidgets('marcar todas como leídas limpia el contador y el badge', (
    tester,
  ) async {
    final service = _FakeNotificacionesApi(
      unreadCount: 2,
      items: [_item('n-1'), _item('n-2')],
    );
    final provider = await createProvider(tester, service);
    await provider.cargarInicial();
    await tester.pumpWidget(
      ChangeNotifierProvider<NotificacionesProvider>.value(
        value: provider,
        child: MaterialApp(theme: darkTheme, home: const NotificacionesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Marcar todas como leídas'), findsOneWidget);
    await tester.tap(find.text('Marcar todas como leídas'));
    await tester.pumpAndSettle();

    expect(provider.unreadCount, 0);
    expect(provider.items.every((item) => item.estaLeida), isTrue);
    expect(find.text('Marcar todas como leídas'), findsNothing);
  });

  testWidgets('error de carga ofrece reintentar y recupera la lista', (
    tester,
  ) async {
    final service = _FakeNotificacionesApi(items: [_item('n-1')])
      ..falloAlListar = StateError('backend temporalmente no disponible');
    final provider = await createProvider(tester, service);
    await tester.pumpWidget(
      ChangeNotifierProvider<NotificacionesProvider>.value(
        value: provider,
        child: MaterialApp(theme: darkTheme, home: const NotificacionesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No pudimos cargar tus notificaciones'), findsOneWidget);
    service.falloAlListar = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva cotización'), findsOneWidget);
  });

  testWidgets('lista pagina con hasMore y anuncia el fin de la lista', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final service = _FakeNotificacionesApi(
      items: [
        for (var index = 1; index <= 21; index++)
          _item('n-$index', titulo: 'Notificación $index'),
      ],
    );
    final provider = await createProvider(tester, service);
    await tester.pumpWidget(
      ChangeNotifierProvider<NotificacionesProvider>.value(
        value: provider,
        child: MaterialApp(theme: darkTheme, home: const NotificacionesPage()),
      ),
    );
    await tester.pumpAndSettle();
    final llamadasIniciales = service.listCalls;
    expect(find.text('Notificación 21'), findsNothing);

    await tester.fling(
      find.byType(ListView).first,
      const Offset(0, -1800),
      2400,
    );
    await tester.pumpAndSettle();

    expect(service.listCalls, greaterThan(llamadasIniciales));
    expect(find.text('Notificación 21'), findsOneWidget);
    await tester.fling(
      find.byType(ListView).first,
      const Offset(0, -800),
      1800,
    );
    await tester.pumpAndSettle();
    expect(find.text('No hay más notificaciones'), findsOneWidget);
  });

  testWidgets('si PATCH de leída falla, revierte el item y el contador', (
    tester,
  ) async {
    final service = _FakeNotificacionesApi(
      unreadCount: 1,
      items: [_item('n-1')],
    )..falloAlMarcarLeida = StateError('offline');
    final provider = await createProvider(tester, service);
    await provider.cargarInicial();

    await expectLater(provider.marcarLeida('n-1'), throwsStateError);
    expect(provider.unreadCount, 1);
    expect(provider.items.single.estaLeida, isFalse);
  });

  testWidgets('pull-to-refresh vuelve a consultar lista y conteo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final service = _FakeNotificacionesApi(items: [_item('n-1')]);
    final provider = await createProvider(tester, service);
    await tester.pumpWidget(
      ChangeNotifierProvider<NotificacionesProvider>.value(
        value: provider,
        child: MaterialApp(theme: darkTheme, home: NotificacionesPage()),
      ),
    );
    await tester.pumpAndSettle();
    final listCalls = service.listCalls;
    final unreadCalls = service.unreadCalls;

    await tester.fling(find.byType(ListView).first, const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(service.listCalls, greaterThan(listCalls));
    expect(service.unreadCalls, greaterThan(unreadCalls));
  });
}

Notificacion _item(String id, {DateTime? leidoEn, String? titulo}) =>
    Notificacion(
      id: id,
      tipo: 'cotizacion_recibida',
      titulo: titulo ?? 'Nueva cotización',
      mensaje: 'Un almacén respondió a tu solicitud.',
      payload: const {
        'solicitud_id': 'solicitud-1',
        'cotizacion_id': 'cotizacion-1',
      },
      createdAt: DateTime.utc(2026, 10, 17),
      leidoEn: leidoEn,
    );

class _FakeNotificacionesApi extends NotificacionesApiService {
  int unreadCount;
  List<Notificacion> items;
  int listCalls = 0;
  int unreadCalls = 0;
  int marcarLeidaCalls = 0;
  Object? falloAlMarcarLeida;
  Object? falloAlListar;
  Completer<DateTime?>? marcarLeidaCompleter;

  _FakeNotificacionesApi({this.unreadCount = 0, this.items = const []});

  @override
  Future<int> contarNoLeidas() async {
    unreadCalls++;
    return unreadCount;
  }

  @override
  Future<PaginaNotificaciones> listar({
    required int page,
    int limit = 20,
  }) async {
    listCalls++;
    if (falloAlListar != null) throw falloAlListar!;
    final start = (page - 1) * limit;
    final end = (start + limit).clamp(0, items.length);
    final pageItems = start >= items.length
        ? <Notificacion>[]
        : items.sublist(start, end);
    return PaginaNotificaciones(
      items: pageItems,
      page: page,
      limit: limit,
      hasMore: end < items.length,
    );
  }

  @override
  Future<DateTime?> marcarLeida(String id) async {
    marcarLeidaCalls++;
    if (falloAlMarcarLeida != null) throw falloAlMarcarLeida!;
    final fecha = marcarLeidaCompleter == null
        ? DateTime.utc(2026, 10, 17)
        : await marcarLeidaCompleter!.future;
    return fecha;
  }

  @override
  Future<int> marcarTodasLeidas() async {
    final actualizadas = items.where((item) => !item.estaLeida).length;
    items = items
        .map(
          (item) => item.estaLeida ? item : item.marcadaLeida(DateTime.now()),
        )
        .toList();
    unreadCount = 0;
    return actualizadas;
  }
}

void _expectBellContained(
  WidgetTester tester,
  Finder appBar,
  double screenWidth,
) {
  final appBarRect = tester.getRect(appBar);
  final bellFinder = find.descendant(
    of: appBar,
    matching: find.byType(RyNotificationBell),
  );
  expect(bellFinder, findsOneWidget);
  final bellRect = tester.getRect(bellFinder);
  expect(bellRect.width, 48);
  expect(bellRect.height, 48);
  expect(bellRect.left, greaterThanOrEqualTo(appBarRect.left));
  expect(bellRect.right, lessThanOrEqualTo(appBarRect.right));
  expect(appBarRect.width, screenWidth);
}
