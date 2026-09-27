import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:repuestosya/models/part_catalog.dart';
import 'package:repuestosya/pages/create_request_page.dart';
import 'package:repuestosya/providers/create_request_provider.dart';
import 'package:repuestosya/providers/solicitudes_provider.dart';
import 'package:repuestosya/services/auth_service.dart';
import 'package:repuestosya/services/ubicacion_service.dart';
import 'package:repuestosya/utils/api_error_handler.dart';

import '../helpers/fake_connectivity.dart';
import '../helpers/fake_services.dart';
import '../helpers/fake_solicitud_repository.dart';

/// Formulario crítico "Crear Solicitud" (Fase 2 de docs/TESTING.md):
/// 1. El envío se BLOQUEA con datos inválidos y la llamada al servicio nunca
///    se dispara.
/// 2. Un 422 del backend se asocia al campo correcto en la UI vía
///    `mapValidationErrors`.
///
/// Todos los servicios están inyectados como dobles; no hay red real.
void main() {
  late FakeConnectivityPlatform conectividad;
  late FakeSolicitudService solicitud;
  late FakeVehiculoService vehiculos;
  late FakeDireccionService direcciones;
  late FakeCatalogService catalogo;

  setUp(() {
    conectividad = FakeConnectivityPlatform();
    ConnectivityPlatform.instance = conectividad;

    solicitud = FakeSolicitudService();
    vehiculos = FakeVehiculoService()
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
    direcciones = FakeDireccionService()
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
    catalogo = FakeCatalogService()
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

    AuthService().currentUserForTesting = User(id: 'u-1', email: 'c@x.com');
  });

  tearDown(() {
    AuthService().currentUserForTesting = null;
  });

  Future<void> pumpForm(
    WidgetTester tester, {
    CreateRequestProvider? provider,
  }) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final formProvider = provider ?? CreateRequestProvider();
    final solicitudesProvider = SolicitudesProvider(
      FakeSolicitudRepository()..setOnline(true),
    );
    addTearDown(solicitudesProvider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<CreateRequestProvider>.value(
        value: formProvider,
        child: ChangeNotifierProvider<SolicitudesProvider>.value(
          value: solicitudesProvider,
          child: MaterialApp(
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
    // Deja que terminen las cargas iniciales (vehículos, direcciones,
    // categorías) — todas con dobles, sin red.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<void> seleccionarVehiculo(WidgetTester tester) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toyota Corolla (VIN: ...8901)').last);
    await tester.pumpAndSettle();
  }

  group('bloqueo del envío con datos inválidos', () {
    testWidgets('campo obligatorio vacío: error visible y servicio nunca '
        'invocado', (tester) async {
      await pumpForm(tester);

      // Dirección con coordenadas auto-seleccionada → botón habilitado.
      expect(find.text('BUSCAR REPUESTO'), findsOneWidget);

      await tester.tap(find.text('BUSCAR REPUESTO'));
      await tester.pump();

      // El validator del formulario bloquea: error de campo visible...
      expect(
        find.text(
          'Por favor ingresa detalles adicionales para ayudar a identificar tu repuesto.',
        ),
        findsOneWidget,
      );
      // ...y el servicio NUNCA se llamó.
      expect(solicitud.crearSolicitudCalls, 0);
    });

    testWidgets('formato incorrecto (descripción < 10 caracteres): bloqueado', (
      tester,
    ) async {
      final provider = CreateRequestProvider()
        ..updatePiezaNombre('Filtro')
        ..setSelectedCategoryId('cat-1')
        ..setSelectedPartId('rep-1', 'Pastillas de freno')
        ..updateVehiculo('v-1')
        ..updateDescripcion('abc');
      await pumpForm(tester, provider: provider);
      await seleccionarVehiculo(tester);

      await tester.tap(find.text('BUSCAR REPUESTO'));
      await tester.pump();

      expect(
        find.text(
          'La descripción es muy corta. Ingresa al menos 10 caracteres (ej: marca, lado, color).',
        ),
        findsOneWidget,
      );
      expect(solicitud.crearSolicitudCalls, 0);
    });
  });

  group('error 422 asociado al campo', () {
    testWidgets('el backend responde 422 con field/message → el error se '
        'muestra bajo el campo correspondiente y sin SnackBar genérico', (
      tester,
    ) async {
      final provider = CreateRequestProvider()
        ..updatePiezaNombre('Filtro')
        ..setSelectedCategoryId('cat-1')
        ..setSelectedPartId('rep-1', 'Pastillas de freno')
        ..updateVehiculo('v-1')
        ..updateDescripcion('Amortiguador delantero derecho marca original');
      solicitud.falloAlCrear = ApiErrorHandler.fromResponse(
        http.Response(
          '{"errors":[{"field":"descripcion","message":"La descripción debe mencionar la marca del repuesto"}]}',
          422,
        ),
      );
      await pumpForm(tester, provider: provider);
      await seleccionarVehiculo(tester);

      await tester.tap(find.text('BUSCAR REPUESTO'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // El servicio SÍ se llamó (los datos eran válidos)...
      expect(solicitud.crearSolicitudCalls, 1);
      // ...y el error 422 quedó asociado al campo 'descripcion' en la UI.
      expect(
        find.text('La descripción debe mencionar la marca del repuesto'),
        findsOneWidget,
      );
      // Sin SnackBar genérico: el error tiene dueño (campo).
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}

/// Doble de UbicacionService: nunca debería invocarse en estos tests porque
/// la dirección de entrega ya trae coordenadas (ubicación resuelta).
class _FakeUbicacion extends UbicacionService {
  int llamadas = 0;

  @override
  Future<UbicacionResultado> obtenerUbicacion({
    int intentos = UbicacionService.maxIntentos,
  }) async {
    llamadas++;
    return const UbicacionResultado(
      estado: UbicacionEstado.noDisponible,
      mensaje: 'el GPS no debería usarse en este test',
    );
  }

  @override
  Future<bool> abrirAjustes() async => true;

  @override
  Future<bool> abrirAjustesSistema() async => true;
}
