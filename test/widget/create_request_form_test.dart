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
import 'package:repuestosya/widgets/ry_button.dart';

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
    Size viewport = const Size(800, 2200),
    bool isOnboardingFlow = false,
  }) async {
    tester.view.physicalSize = viewport;
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
              isOnboardingFlow: isOnboardingFlow,
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

  testWidgets(
    'el vehículo aparece primero y la ubicación pendiente solo se indica '
    'dentro de su tarjeta',
    (tester) async {
      direcciones.respuestaDirecciones = [
        {
          'id': 'd-1',
          'alias': 'Casa',
          'calle_principal': 'Av. 10 de Agosto',
          'es_principal': true,
        },
      ];
      await pumpForm(tester);

      Finder requiredLabel(String label) => find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().trim() == '$label *',
      );

      final orderedElements = [
        requiredLabel('Selecciona tu vehículo'),
        find.text('Toca para seleccionar'),
        requiredLabel('Categoría de repuesto'),
        requiredLabel('Repuesto'),
        find.text('Detalles adicionales'),
        find.text('Repuestos adicionales'),
        find.text('Prioridad de la solicitud'),
        find.text('Ubicación de entrega'),
      ];

      for (var index = 0; index < orderedElements.length - 1; index++) {
        expect(
          tester.getTopLeft(orderedElements[index]).dy,
          lessThan(tester.getTopLeft(orderedElements[index + 1]).dy),
        );
      }

      expect(find.text('Pendiente de verificar'), findsOneWidget);
      expect(find.textContaining('Ubicación pendiente — toca'), findsNothing);
      expect(find.text('BUSCAR REPUESTO'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('el estado de ubicación no desborda en pantalla compacta', (
    tester,
  ) async {
    direcciones.respuestaDirecciones = [
      {
        'id': 'd-1',
        'alias': 'Casa',
        'calle_principal': 'Av. 10 de Agosto',
        'es_principal': true,
      },
    ];
    await pumpForm(tester, viewport: const Size(320, 720));

    final pendingStatus = find.text('Pendiente de verificar');
    expect(pendingStatus, findsOneWidget);
    await tester.ensureVisible(pendingStatus);
    await tester.pumpAndSettle();

    final statusRect = tester.getRect(pendingStatus);
    expect(statusRect.left, greaterThanOrEqualTo(0));
    expect(statusRect.right, lessThanOrEqualTo(320));
    final changeLocationButton = find.byTooltip('Cambiar ubicación');
    expect(changeLocationButton, findsOneWidget);
    expect(tester.getRect(changeLocationButton).right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
  });

  testWidgets('el selector sin direcciones muestra un CTA prominente', (
    tester,
  ) async {
    direcciones.respuestaDirecciones = [];
    await pumpForm(tester);

    await tester.tap(find.byTooltip('Cambiar ubicación'));
    await tester.pumpAndSettle();

    expect(find.text('Aún no tienes direcciones'), findsOneWidget);
    final addButton = tester.widget<RyButton>(
      find.byWidgetPredicate(
        (widget) => widget is RyButton && widget.label == 'Agregar dirección',
      ),
    );
    expect(addButton.variant, RyButtonVariant.primary);
    expect(addButton.size, RyButtonSize.large);
    expect(addButton.isFullWidth, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'el selector de direcciones permite desplazar el contenido en horizontal',
    (tester) async {
      direcciones.respuestaDirecciones = List.generate(
        8,
        (index) => {
          'id': 'd-$index',
          'alias': 'Dirección $index',
          'calle_principal':
              'Avenida principal número $index, sector residencial norte',
          'es_principal': index == 0,
        },
      );
      await pumpForm(tester, viewport: const Size(640, 360));

      final changeLocation = find.byTooltip('Cambiar ubicación');
      await tester.ensureVisible(changeLocation);
      await tester.pumpAndSettle();
      await tester.tap(changeLocation);
      await tester.pumpAndSettle();

      expect(find.text('Seleccionar dirección de entrega'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(
        tester.getRect(find.text('Cancelar')).bottom,
        lessThanOrEqualTo(360),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'la gestión de repuestos adicionales usa CTAs secundarios y se colapsa '
    'al agregar a la lista',
    (tester) async {
      final provider = CreateRequestProvider();
      await pumpForm(
        tester,
        provider: provider,
        viewport: const Size(320, 720),
      );

      RyButton buttonWithLabel(String label) => tester.widget<RyButton>(
        find.byWidgetPredicate(
          (widget) => widget is RyButton && widget.label == label,
        ),
      );

      expect(
        buttonWithLabel('Agregar otro repuesto').variant,
        RyButtonVariant.outline,
      );
      final addNextAdditionalPart = find.text('Agregar otro repuesto');
      await tester.ensureVisible(addNextAdditionalPart);
      await tester.tap(addNextAdditionalPart);
      await tester.pumpAndSettle();

      final additionalPart = provider.additionalParts.single;
      provider.updateAdditionalCategory(additionalPart.id, 'cat-1', 'Frenos');
      provider.updateAdditionalPart(
        additionalPart.id,
        'rep-1',
        'Pastillas de freno',
      );
      await tester.pumpAndSettle();

      expect(
        buttonWithLabel('Agregar a la lista').variant,
        RyButtonVariant.outline,
      );
      final addToList = find.text('Agregar a la lista');
      await tester.ensureVisible(addToList);
      await tester.tap(addToList);
      await tester.pumpAndSettle();

      expect(find.text('Pastillas de freno'), findsOneWidget);
      expect(find.text('Agregar a la lista'), findsNothing);
      expect(find.byTooltip('Eliminar repuesto adicional'), findsOneWidget);
      expect(find.text('Repuesto 1'), findsNothing);

      final addAnother = find.text('Agregar otro repuesto');
      await tester.ensureVisible(addAnother);
      await tester.tap(addAnother);
      await tester.pumpAndSettle();

      expect(find.text('Nuevo repuesto'), findsOneWidget);
      expect(find.text('Pastillas de freno'), findsOneWidget);
      expect(find.text('Agregar a la lista'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

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

  testWidgets(
    'confirma el envío con un diálogo de éxito y acceso a solicitudes',
    (tester) async {
      final provider = CreateRequestProvider()
        ..updatePiezaNombre('Filtro')
        ..setSelectedCategoryId('cat-1')
        ..setSelectedPartId('rep-1', 'Pastillas de freno')
        ..updateVehiculo('v-1')
        ..updateDescripcion('Pastillas delanteras para Toyota Corolla');
      await pumpForm(tester, provider: provider, isOnboardingFlow: true);
      await seleccionarVehiculo(tester);

      await tester.tap(find.text('BUSCAR REPUESTO'));
      await tester.pumpAndSettle();

      expect(find.text('¡Solicitud enviada con éxito!'), findsOneWidget);
      expect(
        find.text(
          'Los almacenes ya están revisando lo que necesitas. '
          'Te notificaremos en cuanto recibas las primeras cotizaciones.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.text('Continuar'), findsOneWidget);
      expect(find.text('Ver mis solicitudes'), findsNothing);
      expect(find.text('OK'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
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
