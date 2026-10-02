import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
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

  Future<void> pumpForm(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 900);
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

      // El footer ("Certificado ISO 9001 | SSL Secure") queda CENTRADO en la
      // pantalla, no pegado a la izquierda (regresión del Wrap).
      final centroViewport = tester.view.physicalSize.width / 2;
      for (final texto in ['Certificado ISO 9001', 'SSL Secure']) {
        final rect = tester.getRect(find.text(texto));
        final centroTexto = rect.center.dx;
        expect(
          (centroTexto - centroViewport).abs(),
          lessThan(30),
          reason:
              '"$texto" debe quedar centrado (centro $centroTexto '
              'vs viewport $centroViewport)',
        );
      }
    },
  );

  testWidgets(
    'Parte 2: el texto de ayuda de "Detalles adicionales" se ve completo '
    '(helper con wrap, no truncado a 1 línea)',
    (tester) async {
      await pumpForm(tester);

      const helper =
          'Ej: Amortiguador delantero derecho, marca original o equivalente de alta calidad';
      final helperFinder = find.text(helper);
      expect(
        helperFinder,
        findsOneWidget,
        reason: 'El texto de ayuda completo debe existir en el árbol',
      );

      // El helper renderiza con wrap (más de una línea): si estuviera
      // truncado a 1 línea mediría ~20px.
      final alto = tester.getSize(helperFinder).height;
      expect(
        alto,
        greaterThan(30),
        reason: 'El helper debe hacer wrap (alto $alto px = 1 línea truncada)',
      );
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
