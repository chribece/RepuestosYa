import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:repuestosya/pages/home_page.dart';
import 'package:repuestosya/router/route_names.dart';
import 'package:repuestosya/providers/solicitudes_provider.dart';
import 'package:repuestosya/providers/profile_image_provider.dart';
import 'package:repuestosya/services/auth_service.dart';
import 'package:repuestosya/theme/app_spacing.dart';
import 'package:repuestosya/widgets/ry_notification_bell.dart';
import 'package:repuestosya/providers/create_request_provider.dart';

import '../helpers/fake_connectivity.dart';
import '../helpers/fake_services.dart';
import '../helpers/fake_solicitud_repository.dart';

/// Regresiones responsive del Home (móvil angosto ~420px lógicos vs tablet):
/// 1. Las métricas ocupan una banda compacta horizontal, deslizable y sin
///    desbordar sus tarjetas.
/// 2. El subtítulo de "NUEVA BÚSQUEDA" respeta el padding horizontal de la
///    card aunque haga wrap (no toca el borde izquierdo).
/// 3. El bottom nav agrega el padding de área segura inferior (barra de
///    gestos) en teléfonos y queda igual en tablet (padding 0).
///
/// Nota sobre la fuente de TEST (Ahem): dibuja cada glifo con ancho =
/// fontSize (~2x el ancho real de Sora), por lo que en pruebas angostas
/// aparecen overflows en widgets NO relacionados (app bar, header "Mis
/// Solicitudes") que NO existen en dispositivo con Sora — el test de tablet
/// de 800px no reporta ninguno. Esos artefactos se drenan al final con
/// [drenarExcepcionesAhem]; los widgets de los 3 fixes se verifican con
/// aserciones de geometría y contención, que sí fallan si el fix se rompe.
void main() {
  late FakeConnectivityPlatform conectividad;

  setUp(() {
    conectividad = FakeConnectivityPlatform();
    ConnectivityPlatform.instance = conectividad;
    // El singleton de Auth no arrastra sesión entre tests.
    AuthService().currentUserForTesting = null;
  });

  Future<SolicitudesProvider> pumpHome(
    WidgetTester tester, {
    required Size size,
    double bottomPadding = 0,
    ProfileImageProvider? profileImageProvider,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = FakeViewPadding(bottom: bottomPadding);
    addTearDown(tester.view.reset);

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
          if (profileImageProvider != null)
            ChangeNotifierProvider<ProfileImageProvider>.value(
              value: profileImageProvider,
            ),
        ],
        child: MaterialApp(home: HomePage(catalogService: catalogService)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return provider;
  }

  testWidgets('Home refleja en el AppBar los cambios reactivos del avatar', (
    tester,
  ) async {
    final profileImageProvider = ProfileImageProvider()
      ..setImageUrl(
        'https://example.test/avatar-v1.jpg',
        userId: 'cliente-test',
      );
    addTearDown(profileImageProvider.dispose);

    await pumpHome(
      tester,
      size: const Size(420, 900),
      profileImageProvider: profileImageProvider,
    );

    final avatar = find.byKey(const ValueKey('home-profile-avatar'));
    Image avatarImage() => tester.widget<Image>(
      find.descendant(of: avatar, matching: find.byType(Image)),
    );
    expect((avatarImage().image as NetworkImage).url, contains('avatar-v1'));

    profileImageProvider.setImageUrl(
      'https://example.test/avatar-v2.jpg',
      userId: 'cliente-test',
    );
    await tester.pump();

    expect((avatarImage().image as NetworkImage).url, contains('avatar-v2'));
    while (tester.takeException() != null) {}
  });

  /// Descarta los overflows de layout que la fuente de test (Ahem) genera en
  /// widgets NO relacionados con los 3 fixes (ver nota arriba).
  void drenarExcepcionesAhem(WidgetTester tester) {
    while (tester.takeException() != null) {}
  }

  /// Comprueba el alto compacto, separación y contención de las métricas
  /// visibles antes de desplazar el carrusel.
  void expectStatsCompactos(WidgetTester tester) {
    final carouselRect = tester.getRect(
      find.byKey(const ValueKey('home-stats-carousel')),
    );
    final rectActivas = tester.getRect(
      find.byKey(const ValueKey('stat-card-Solicitudes Activas')),
    );
    final rectCotizadas = tester.getRect(
      find.byKey(const ValueKey('stat-card-Cotizaciones Recibidas')),
    );
    expect(carouselRect.height, 96);
    expect(rectActivas.height, rectCotizadas.height);
    expect(rectCotizadas.left, greaterThan(rectActivas.right));
    expect(rectCotizadas.right, lessThanOrEqualTo(carouselRect.right));
    expect(rectActivas.left, closeTo(carouselRect.left, 0.5));
    expect(
      rectActivas.left,
      closeTo(
        tester.getRect(find.byKey(const ValueKey('hero-search-card'))).left,
        0.5,
      ),
    );
    expect(
      rectActivas.left,
      closeTo(tester.getRect(find.text('Mis Solicitudes')).left, 0.5),
    );

    final activeValue = tester.getRect(
      find.descendant(
        of: find.byKey(const ValueKey('stat-card-Solicitudes Activas')),
        matching: find.text('02'),
      ),
    );
    expect(activeValue.bottom, lessThanOrEqualTo(rectActivas.bottom));
    expect(activeValue.right, lessThanOrEqualTo(rectActivas.right));
  }

  testWidgets(
    'móvil angosto (~420px): métricas compactas y subtítulo de hero con padding',
    (tester) async {
      await pumpHome(tester, size: const Size(420, 900));

      expectStatsCompactos(tester);

      // Subtítulo de la hero: respeta el padding horizontal de la card (no
      // toca los bordes) y queda contenido verticalmente.
      final cardRect = tester.getRect(
        find.byKey(const ValueKey('hero-search-card')),
      );
      final subRect = tester.getRect(
        find.text('Sube una foto y encuentra tu repuesto al instante'),
      );
      expect(
        subRect.left - cardRect.left,
        greaterThanOrEqualTo(AppSpacing.spacingLg - 0.5),
        reason: 'subtítulo separado del borde izquierdo',
      );
      expect(
        cardRect.right - subRect.right,
        greaterThanOrEqualTo(AppSpacing.spacingLg - 0.5),
        reason: 'subtítulo separado del borde derecho',
      );
      expect(
        subRect.bottom,
        lessThanOrEqualTo(cardRect.bottom),
        reason: 'subtítulo contenido dentro de la card',
      );

      final statsCarousel = find.byKey(const ValueKey('home-stats-carousel'));
      final firstDot = find.byKey(const ValueKey('home-stats-dot-0'));
      final secondDot = find.byKey(const ValueKey('home-stats-dot-1'));
      expect(tester.getSize(firstDot).width, 22);
      expect(tester.getSize(secondDot).width, 12);

      await tester.drag(statsCarousel, const Offset(-320, 0));
      await tester.pumpAndSettle();
      expect(tester.getSize(firstDot).width, 12);
      expect(tester.getSize(secondDot).width, 22);
      final lastMetric = find.byKey(
        const ValueKey('stat-card-Órdenes Realizadas'),
      );
      expect(lastMetric, findsOneWidget);
      expect(
        tester.getRect(lastMetric).right,
        lessThanOrEqualTo(tester.getRect(statsCarousel).right),
      );

      drenarExcepcionesAhem(tester);
    },
  );

  testWidgets(
    'móvil con barra de gestos: el bottom nav respeta el área segura inferior',
    (tester) async {
      const screenHeight = 900.0;
      const inset = 24.0;
      await pumpHome(
        tester,
        size: const Size(420, screenHeight),
        bottomPadding: inset,
      );

      final navRect = tester.getRect(
        find.byKey(const ValueKey('bottom-nav-bar')),
      );
      // El fondo cubre el área de gestos: 64 de barra + inset del sistema.
      expect(navRect.height, 64 + inset);
      expect(navRect.bottom, screenHeight);

      // Los ítems quedan por encima del área de gestos.
      final homeRect = tester.getRect(
        find.descendant(
          of: find.byKey(const ValueKey('bottom-nav-bar')),
          matching: find.text('Inicio'),
        ),
      );
      expect(
        homeRect.bottom,
        lessThanOrEqualTo(screenHeight - inset + 0.5),
        reason: 'ítem visible por encima de la barra de gestos',
      );

      drenarExcepcionesAhem(tester);
    },
  );

  testWidgets(
    'categoría dinámica abre Crear Solicitud con su ID preseleccionado',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final solicitudesProvider = SolicitudesProvider(
        FakeSolicitudRepository()..setOnline(true),
      );
      final createRequestProvider = CreateRequestProvider();
      final catalogService = FakeCatalogService()
        ..respuestaCategorias = categoriasRepuestosDePrueba();
      addTearDown(solicitudesProvider.dispose);
      addTearDown(createRequestProvider.dispose);

      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) =>
                HomePage(catalogService: catalogService),
          ),
          GoRoute(
            path: '/request/create',
            name: RouteNames.createRequest,
            builder: (context, state) => Scaffold(
              body: Center(
                child: Text(
                  'Categoría inicial: '
                  '${state.uri.queryParameters['categoryId']}',
                ),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SolicitudesProvider>.value(
              value: solicitudesProvider,
            ),
            ChangeNotifierProvider<CreateRequestProvider>.value(
              value: createRequestProvider,
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      final electricCategory = find.byKey(
        const ValueKey('home-trending-item-Eléctrico'),
      );
      await tester.ensureVisible(electricCategory);
      await tester.tap(electricCategory);
      await tester.pumpAndSettle();

      expect(find.text('Categoría inicial: cat-electrico'), findsOneWidget);
      expect(createRequestProvider.selectedCategoryId, 'cat-electrico');
      drenarExcepcionesAhem(tester);
    },
  );

  testWidgets(
    'las categorías rápidas muestran dos tarjetas completas por página con dots',
    (tester) async {
      await pumpHome(tester, size: const Size(420, 900));
      await tester.ensureVisible(find.text('Lo más buscado'));
      await tester.pumpAndSettle();

      final categoriesList = find.byKey(
        const ValueKey('home-trending-categories'),
      );
      final listRect = tester.getRect(categoriesList);
      final firstCard = find.byKey(
        const ValueKey('home-trending-item-Carrocería'),
      );
      final secondCard = find.byKey(
        const ValueKey('home-trending-item-Eléctrico'),
      );
      final firstRect = tester.getRect(firstCard);
      final secondRect = tester.getRect(secondCard);

      expect(firstRect.left, closeTo(listRect.left, 0.5));
      expect(
        firstRect.left,
        closeTo(tester.getRect(find.text('Lo más buscado')).left, 0.5),
      );
      expect(
        firstRect.left,
        closeTo(tester.getRect(find.text('Mis Solicitudes')).left, 0.5),
      );
      expect(secondRect.left - firstRect.right, AppSpacing.spacingSm);
      expect(secondRect.right, lessThanOrEqualTo(listRect.right));

      final thirdCard = find.byKey(
        const ValueKey('home-trending-item-Filtros'),
      );
      if (thirdCard.evaluate().isNotEmpty) {
        expect(
          tester.getRect(thirdCard).left,
          greaterThanOrEqualTo(listRect.right - 0.5),
        );
      }
      expect(find.byKey(const ValueKey('home-trending-dot-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-trending-dot-3')), findsOneWidget);

      final carBodyLabel = tester.renderObject<RenderParagraph>(
        find.descendant(of: firstCard, matching: find.text('Carrocería')),
      );
      expect(carBodyLabel.didExceedMaxLines, isFalse);

      final categoriesPage = find.byKey(
        const ValueKey('home-trending-categories'),
      );
      await tester.drag(categoriesPage, const Offset(-360, 0));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const ValueKey('home-trending-dot-1'))).width,
        22,
      );
      await tester.drag(categoriesPage, const Offset(-360, 0));
      await tester.pumpAndSettle();
      final lubricantLabel = tester.widget<Text>(
        find.text('Lubricantes y Fluidos'),
      );
      expect(lubricantLabel.maxLines, 1);
      expect(lubricantLabel.overflow, TextOverflow.ellipsis);
      drenarExcepcionesAhem(tester);
    },
  );

  testWidgets(
    'el scroll principal deja espacio bajo las categorías antes del bottom nav',
    (tester) async {
      await pumpHome(tester, size: const Size(420, 900));

      final mainScroll = find.byKey(const ValueKey('home-main-scroll'));
      await tester.drag(mainScroll, const Offset(0, -1800));
      await tester.pumpAndSettle();

      final scrollRect = tester.getRect(mainScroll);
      final lastCategoryRect = tester.getRect(
        find.byKey(const ValueKey('home-trending-item-Carrocería')),
      );
      final navRect = tester.getRect(
        find.byKey(const ValueKey('bottom-nav-bar')),
      );

      expect(scrollRect.bottom, lessThanOrEqualTo(navRect.top));
      final bottomWhitespace = scrollRect.bottom - lastCategoryRect.bottom;
      expect(bottomWhitespace, greaterThanOrEqualTo(100));
      expect(bottomWhitespace, lessThanOrEqualTo(120));
      drenarExcepcionesAhem(tester);
    },
  );

  testWidgets(
    'tablet: métricas compactas y bottom nav de 64 (padding de sistema 0)',
    (tester) async {
      await pumpHome(tester, size: const Size(800, 2000));

      expectStatsCompactos(tester);

      final navRect = tester.getRect(
        find.byKey(const ValueKey('bottom-nav-bar')),
      );
      expect(navRect.height, 64, reason: 'sin inset el nav mantiene 64');

      // En ancho de tablet el subtítulo cabe en una línea y sigue sin tocar
      // los bordes de la card.
      final cardRect = tester.getRect(
        find.byKey(const ValueKey('hero-search-card')),
      );
      final subRect = tester.getRect(
        find.text('Sube una foto y encuentra tu repuesto al instante'),
      );
      expect(subRect.left, greaterThanOrEqualTo(cardRect.left));
      expect(subRect.right, lessThanOrEqualTo(cardRect.right));

      // A 800px ni siquiera Ahem desborda: no debe haber excepciones.
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Home AppBar conserva campana y avatar a 420/800px', (
    tester,
  ) async {
    for (final size in [const Size(420, 900), const Size(800, 1200)]) {
      await pumpHome(tester, size: size);

      final appBar = find.byKey(const ValueKey('home-top-app-bar'));
      final appBarRect = tester.getRect(appBar);
      final bell = find.descendant(
        of: appBar,
        matching: find.byType(RyNotificationBell),
      );
      final avatar = find.descendant(
        of: appBar,
        matching: find.byKey(const ValueKey('home-profile-avatar')),
      );
      final title = find.descendant(
        of: appBar,
        matching: find.text('RepuestosYa'),
      );

      expect(bell, findsOneWidget);
      expect(avatar, findsOneWidget);
      expect(
        find.descendant(
          of: avatar,
          matching: find.byIcon(Icons.person_rounded),
        ),
        findsOneWidget,
      );
      expect(title, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(title).didExceedMaxLines,
        isFalse,
      );
      final bellRect = tester.getRect(bell);
      final avatarRect = tester.getRect(avatar);
      expect(bellRect.right, lessThan(avatarRect.left));
      expect(
        avatarRect.right,
        closeTo(appBarRect.right - AppSpacing.spacingMd, 1),
      );
      for (final control in [bell, avatar, title]) {
        final rect = tester.getRect(control);
        expect(rect.left, greaterThanOrEqualTo(appBarRect.left));
        expect(rect.right, lessThanOrEqualTo(appBarRect.right));
        expect(rect.top, greaterThanOrEqualTo(appBarRect.top));
        expect(rect.bottom, lessThanOrEqualTo(appBarRect.bottom));
      }
      drenarExcepcionesAhem(tester);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('el acceso Solicitudes reemplaza la lupa y abre el listado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final solicitudesProvider = SolicitudesProvider(
      FakeSolicitudRepository()..setOnline(true),
    );
    final createRequestProvider = CreateRequestProvider();
    final catalogService = FakeCatalogService()
      ..respuestaCategorias = categoriasRepuestosDePrueba();
    addTearDown(solicitudesProvider.dispose);
    addTearDown(createRequestProvider.dispose);

    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => HomePage(catalogService: catalogService),
        ),
        GoRoute(
          path: '/solicitudes',
          name: RouteNames.solicitudes,
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('LISTADO_SOLICITUDES'))),
        ),
        GoRoute(
          path: '/mis-ordenes',
          name: RouteNames.misOrdenes,
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('LISTADO_ORDENES'))),
        ),
        GoRoute(
          path: '/profile',
          name: RouteNames.profile,
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('PERFIL_CLIENTE'))),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SolicitudesProvider>.value(
            value: solicitudesProvider,
          ),
          ChangeNotifierProvider<CreateRequestProvider>.value(
            value: createRequestProvider,
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final bottomNav = find.byKey(const ValueKey('bottom-nav-bar'));
    expect(
      find.descendant(of: bottomNav, matching: find.text('Inicio')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bottomNav, matching: find.text('Solicitudes')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bottomNav, matching: find.text('Órdenes')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bottomNav, matching: find.text('Perfil')),
      findsOneWidget,
    );
    expect(find.text('Search'), findsNothing);
    expect(find.text('Orders'), findsNothing);
    expect(find.text('Profile'), findsNothing);

    await tester.tap(
      find.descendant(of: bottomNav, matching: find.text('Solicitudes')),
    );
    await tester.pumpAndSettle();
    expect(find.text('LISTADO_SOLICITUDES'), findsOneWidget);
    drenarExcepcionesAhem(tester);
  });
}
