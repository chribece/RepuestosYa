import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:repuestosya/database/app_database.dart';
import 'package:repuestosya/models/part_catalog.dart';
import 'package:repuestosya/pages/create_request_page.dart';
import 'package:repuestosya/pages/login_page.dart';
import 'package:repuestosya/providers/create_request_provider.dart';
import 'package:repuestosya/providers/solicitudes_provider.dart';
import 'package:repuestosya/services/almacen_repository.dart';
import 'package:repuestosya/services/auth_service.dart';
import 'package:repuestosya/services/ubicacion_service.dart';
import 'package:repuestosya/theme/app_theme.dart';
import 'package:repuestosya/widgets/ry_bottom_action_bar.dart';

import '../helpers/fake_connectivity.dart';
import '../helpers/fake_services.dart';
import '../helpers/fake_solicitud_repository.dart';

/// Fixes de layout móvil (Partes 1 y 2) sobre el formulario "Crear
/// Solicitud" a 420 px:
/// (a) la barra de acción inferior respeta el inset (barra de gestos): el
///     fondo llega al borde real y el botón queda por encima del área segura;
/// (b) el texto de ayuda de "Detalles adicionales" se ve completo (wrap, sin
///     truncar).
void main() {
  setUp(() {
    ConnectivityPlatform.instance = FakeConnectivityPlatform();
    AuthService().currentUserForTesting = User(id: 'u-1', email: 'c@x.com');
  });

  tearDown(() {
    AuthService().currentUserForTesting = null;
  });

  Future<void> pumpForm(
    WidgetTester tester, {
    double width = 420,
    double height = 900,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final solicitud = FakeSolicitudService();
    final vehiculos = FakeVehiculoService()
      ..respuestaVehiculos = [
        {
          'id': 'v-1',
          'vin': '8XWXYZ12345678901',
          'modelos_vehiculo': {
            'nombre': 'Corolla',
            'marcas_vehiculo': {'nombre': 'Toyota'},
          },
        },
      ];
    final direcciones = FakeDireccionService()
      ..respuestaDirecciones = [
        {
          'id': 'd-1',
          'alias': 'Casa',
          'calle_principal': 'Av. 10 de Agosto',
          'latitude': -0.1913664,
          'longitude': -78.4930512,
          'es_principal': true,
        },
      ];
    final catalogo = FakeCatalogService()
      ..respuestaCategorias = [
        PartCategory(id: 'cat-1', nombre: 'Frenos', slug: 'frenos'),
      ]
      ..respuestaPartes = [
        CatalogPart(
          id: 'rep-1',
          categoriaId: 'cat-1',
          nombre: 'Pastillas de freno',
          slug: 'pastillas',
        ),
      ];

    final solicitudesProvider = SolicitudesProvider(
      FakeSolicitudRepository()..setOnline(true),
    );
    addTearDown(solicitudesProvider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<CreateRequestProvider>.value(
        value: CreateRequestProvider(),
        child: ChangeNotifierProvider<SolicitudesProvider>.value(
          value: solicitudesProvider,
          child: MaterialApp(
            theme: darkTheme,
            home: CreateRequestPage(
              solicitudService: solicitud,
              vehiculoService: vehiculos,
              direccionService: direcciones,
              catalogService: catalogo,
              ubicacionService: _FakeUbicacion(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
    'Parte 1a: la barra de acción inferior se extiende al borde real y el '
    'botón queda por encima del inset de gestos (34px)',
    (tester) async {
      // Simula la barra de gestos del sistema (móvil con navegación por
      // gestos): el inset inferior real del dispositivo.
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.reset);

      await pumpForm(tester);

      final barra = find.byType(RyBottomActionBar);
      expect(barra, findsOneWidget);

      // El fondo de la barra llega hasta el borde REAL de la pantalla.
      final barraBottom = tester.getBottomLeft(barra).dy;
      expect(barraBottom, 900, reason: 'El fondo debe cubrir el inset');

      // El botón primario queda por ENCIMA del área segura (900 - 34).
      final boton = find.text('BUSCAR REPUESTO');
      final botonBottom = tester.getBottomLeft(boton).dy;
      expect(
        botonBottom,
        lessThanOrEqualTo(900 - 34),
        reason: 'El botón no debe quedar bajo la barra de gestos',
      );
    },
  );

  testWidgets(
    'login a 420px: sin overflow y "¿Aún no tienes cuenta? Regístrate" se '
    've completo (texto + enlace con wrap, no truncado)',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final errores = <FlutterErrorDetails>[];
      final original = FlutterError.onError;
      FlutterError.onError = (details) => errores.add(details);

      await tester.pumpWidget(
        Provider<AlmacenRepository>.value(
          value: AlmacenRepository(db),
          child: MaterialApp(theme: darkTheme, home: const LoginPage()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      FlutterError.onError = original;

      expect(
        errores,
        isEmpty,
        reason:
            'Overflows login 420px:\n'
            '${errores.map((e) => e.exceptionAsString()).join('\n')}',
      );

      // El texto de registro se ve completo: el label ya no es un botón con
      // ellipsis, sino texto + enlace "Regístrate".
      expect(find.text('¿Aún no tienes cuenta? '), findsOneWidget);
      expect(find.text('Regístrate'), findsOneWidget);
      expect(find.text('o continuar con'), findsOneWidget);
      expect(find.text('o'), findsNothing);
      expect(find.byType(Divider), findsNWidgets(2));
      expect(find.text('Continuar con Google'), findsOneWidget);
      expect(
        tester.getBottomLeft(find.text('o continuar con')).dy,
        lessThan(tester.getTopLeft(find.text('Continuar con Google')).dy),
      );
    },
  );

  testWidgets('login sin teclado a 420x900: layout estático, sin scroll', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      Provider<AlmacenRepository>.value(
        value: AlmacenRepository(db),
        child: MaterialApp(theme: darkTheme, home: const LoginPage()),
      ),
    );
    await tester.pump();
    await tester.pump();

    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(scroll.position.maxScrollExtent, 0);
  });

  testWidgets(
    'login con teclado abierto: "Iniciar sesión" queda por encima del teclado',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await tester.pumpWidget(
        Provider<AlmacenRepository>.value(
          value: AlmacenRepository(db),
          child: MaterialApp(theme: darkTheme, home: const LoginPage()),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('••••••••'));
      await tester.pump();
      // El teclado aparece DESPUÉS de enfocar la contraseña (como en un móvil).
      tester.view.viewInsets = const FakeViewPadding(bottom: 400);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      final botonBottom = tester.getBottomLeft(find.text('Iniciar sesión')).dy;
      expect(
        botonBottom,
        lessThanOrEqualTo(900 - 400),
        reason: 'El teclado (400px) tapa el botón principal',
      );

      final tarjeta = find
          .byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color ==
                    const Color(0xFF1E1E1E),
          )
          .first;
      expect(
        tester.getTopLeft(tarjeta).dy,
        greaterThanOrEqualTo(0),
        reason: 'El borde superior de la tarjeta queda cortado al hacer scroll',
      );
    },
  );

  testWidgets(
    'hint y helper de Detalles adicionales no se truncan a 420 y 800 px',
    (tester) async {
      const hint =
          'Lado izquierdo/derecho, amperaje, número de pines o tamaño.';
      const helper =
          'Ej: Marca específica, lado (izq/der) o código del repuesto.';

      for (final width in [420.0, 800.0]) {
        await pumpForm(tester, width: width, height: width == 420 ? 900 : 1600);

        final hintFinder = find.text(hint);
        expect(hintFinder, findsOneWidget);
        final hintParagraph = tester.renderObject<RenderParagraph>(hintFinder);
        debugPrint(
          'DETAILS_HINT width=$width intrinsic='
          '${hintParagraph.getMaxIntrinsicWidth(double.infinity).toStringAsFixed(1)} '
          'available=${hintParagraph.constraints.maxWidth.toStringAsFixed(1)} '
          'didExceedMaxLines=${hintParagraph.didExceedMaxLines}',
        );
        expect(hintParagraph.didExceedMaxLines, isFalse);

        final helperFinder = find.text(helper);
        expect(helperFinder, findsOneWidget);
        final helperParagraph = tester.renderObject<RenderParagraph>(
          helperFinder,
        );
        expect(helperParagraph.didExceedMaxLines, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
}

class _FakeUbicacion extends UbicacionService {
  @override
  Future<UbicacionResultado> obtenerUbicacion({
    int intentos = UbicacionService.maxIntentos,
  }) async {
    return const UbicacionResultado(
      estado: UbicacionEstado.noDisponible,
      mensaje: 'gps no',
    );
  }

  @override
  Future<bool> abrirAjustes() async => true;

  @override
  Future<bool> abrirAjustesSistema() async => true;
}
