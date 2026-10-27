import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:repuestosya/models/notificacion.dart';
import 'package:repuestosya/pages/notificaciones_page.dart';
import 'package:repuestosya/pages/mis_ordenes_page.dart';
import 'package:repuestosya/pages/profile_page.dart';
import 'package:repuestosya/providers/notificaciones_provider.dart';
import 'package:repuestosya/router/route_names.dart';
import 'package:repuestosya/services/almacen_service.dart';
import 'package:repuestosya/services/auth_service.dart';
import 'package:repuestosya/services/notificaciones_api_service.dart';
import 'package:repuestosya/services/profile_service.dart';
import 'package:repuestosya/theme/app_theme.dart';
import 'package:repuestosya/widgets/ry_notification_bell.dart';

import '../helpers/fake_services.dart';

class _FakeProfileService extends ProfileService {
  Map<String, dynamic> profile = {
    'nombre_completo': 'Usuario de prueba',
    'telefono': '+593 0991234567',
    'avatar_url': null,
  };
  int updateCalls = 0;

  @override
  Future<Map<String, dynamic>?> getUserProfile(String userId) async => profile;

  @override
  Future<Map<String, dynamic>?> updateProfile({
    String? nombreCompleto,
    String? telefono,
    String? avatarUrl,
  }) async {
    updateCalls++;
    profile = {
      ...profile,
      'nombre_completo': ?nombreCompleto,
      'telefono': ?telefono,
      'avatar_url': ?avatarUrl,
    };
    return profile;
  }
}

class _FakeAlmacenService extends AlmacenService {
  Map<String, dynamic> warehouse = {'id': 'warehouse-1', 'logo_url': null};

  @override
  Future<Map<String, dynamic>?> obtenerMiAlmacen() async => warehouse;

  @override
  Future<Map<String, dynamic>> actualizarAlmacen(
    String id,
    Map<String, dynamic> data,
  ) async {
    warehouse = {...warehouse, ...data};
    return warehouse;
  }
}

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
        expect(find.text('Provocar fallo de prueba (Sentry)'), findsNothing);
        expect(find.text('Cerrar sesión'), findsWidgets);
        expect(find.byIcon(Icons.logout_rounded), findsWidgets);
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

  testWidgets(
    'guardar perfil muestra confirmación sobria sin recargar la vista',
    (tester) async {
      final profileService = _FakeProfileService();
      await tester.pumpWidget(
        MaterialApp(
          theme: darkTheme,
          home: ProfilePage(profileService: profileService),
        ),
      );
      await tester.pumpAndSettle();

      final campos = find.byType(TextFormField);
      expect(find.text('+593'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(campos.at(1)).controller!.text,
        '991234567',
      );
      expect(find.text('Versión 2.1.0 • Built by VCore Tech'), findsOneWidget);
      await tester.enterText(campos.at(0), 'Ana Actualizada');
      await tester.enterText(campos.at(1), '0998765432');
      await tester.tap(find.byTooltip('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(profileService.updateCalls, 1);
      expect(profileService.profile['telefono'], '998765432');
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Text && widget.data == 'Ana Actualizada',
        ),
        findsOneWidget,
      );
      expect(find.text('Perfil actualizado correctamente'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      final snackbar = tester.widget<SnackBar>(find.byType(SnackBar).last);
      expect(snackbar.backgroundColor, const Color(0xFF1E1E1E));
      expect(snackbar.shape, isA<RoundedRectangleBorder>());
    },
  );

  testWidgets('avatar permite elegir foto y la previsualiza tras guardarla', (
    tester,
  ) async {
    final profileService = _FakeProfileService();
    var uploaderReceivedWarehouseRole = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        home: ProfilePage(
          profileService: profileService,
          imagePicker: (source) async {
            expect(source, ImageSource.gallery);
            return XFile('avatar-test.jpg');
          },
          imageUploader: (file, userId, {required isWarehouse}) async {
            expect(userId, 'user-1');
            uploaderReceivedWarehouseRole = isWarehouse;
            return 'https://example.test/avatar.jpg';
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Actualizar foto de perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Actualizar foto'), findsOneWidget);
    await tester.tap(find.text('Elegir de galería'));
    await tester.pumpAndSettle();

    expect(uploaderReceivedWarehouseRole, isFalse);
    expect(
      profileService.profile['avatar_url'],
      'https://example.test/avatar.jpg',
    );
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('el avatar de almacén identifica la acción como logo comercial', (
    tester,
  ) async {
    AuthService().currentUserForTesting = User(
      id: 'warehouse-1',
      email: 'almacen@test.com',
      rol: 'almacen',
    );
    final profileService = _FakeProfileService();
    final warehouseService = _FakeAlmacenService();
    var uploaderReceivedWarehouseRole = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        home: ProfilePage(
          profileService: profileService,
          warehouseService: warehouseService,
          imagePicker: (source) async => XFile('logo-test.png'),
          imageUploader: (file, userId, {required isWarehouse}) async {
            uploaderReceivedWarehouseRole = isWarehouse;
            return 'https://example.test/logo.png';
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Actualizar logo comercial'));
    await tester.pumpAndSettle();
    expect(find.text('Actualizar logo comercial'), findsOneWidget);
    await tester.tap(find.text('Elegir de galería'));
    await tester.pumpAndSettle();

    expect(uploaderReceivedWarehouseRole, isTrue);
    expect(
      warehouseService.warehouse['logo_url'],
      'https://example.test/logo.png',
    );
    expect(profileService.profile['avatar_url'], isNull);
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
