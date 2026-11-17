import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repuestosya/pages/vehicles_page.dart';
import 'package:repuestosya/services/marca_service.dart';
import 'package:repuestosya/services/modelo_service.dart';
import 'package:repuestosya/services/vehiculo_service.dart';
import 'package:repuestosya/theme/app_theme.dart';
import 'package:repuestosya/widgets/ry_button.dart';

class _FakeVehiculoService extends VehiculoService {
  List<Map<String, dynamic>> vehicles = [];
  int deleteCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> getVehiculos() async => vehicles;

  @override
  Future<void> deleteVehiculo(String id) async {
    deleteCalls++;
    vehicles = [];
  }
}

void main() {
  testWidgets('el estado vacío ofrece una acción principal para agregar '
      'el primer vehículo', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: VehiclesPage(vehiculoService: _FakeVehiculoService())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sin vehículos'), findsOneWidget);
    expect(find.text('Agregar mi primer vehículo'), findsOneWidget);
    expect(find.byTooltip('Agregar vehículo'), findsOneWidget);
    expect(find.byIcon(Icons.directions_car_outlined), findsOneWidget);
    expect(find.byIcon(Icons.inbox_outlined), findsNothing);

    final addButton = tester.widget<RyButton>(
      find.byWidgetPredicate(
        (widget) =>
            widget is RyButton && widget.label == 'Agregar mi primer vehículo',
      ),
    );
    expect(addButton.variant, RyButtonVariant.primary);
    expect(addButton.isFullWidth, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'eliminar vehículo muestra confirmación oscura con contexto y acciones en línea',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final service = _FakeVehiculoService()
        ..vehicles = [
          {
            'id': 'vehicle-1',
            'anio': 2022,
            'modelos_vehiculo': {
              'nombre': 'Corolla',
              'marcas_vehiculo': {'nombre': 'Toyota'},
            },
          },
        ];
      await tester.pumpWidget(
        MaterialApp(
          theme: darkTheme,
          home: VehiclesPage(vehiculoService: service),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Eliminar vehículo'));
      await tester.pumpAndSettle();

      expect(find.text('Eliminar vehículo'), findsOneWidget);
      expect(find.text('Toyota Corolla 2022'), findsOneWidget);
      expect(
        find.text(
          '¿Estás seguro de que deseas eliminar este vehículo? '
          'Esta acción no se puede deshacer.',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(OutlinedButton, 'Cancelar'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Eliminar'), findsOneWidget);
      expect(
        tester.getRect(find.text('Cancelar')).top,
        closeTo(tester.getRect(find.text('Eliminar').last).top, 1),
      );

      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.backgroundColor, const Color(0xFF1E1E1E));
      expect(dialog.shape, isA<RoundedRectangleBorder>());
      final destructiveButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Eliminar'),
      );
      expect(
        destructiveButton.style!.backgroundColor!.resolve({}),
        const Color(0xFFDC2626),
      );
      expect(
        destructiveButton.style!.foregroundColor!.resolve({}),
        Colors.white,
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar'));
      await tester.pumpAndSettle();
      expect(service.deleteCalls, 0);

      await tester.tap(find.byTooltip('Eliminar vehículo'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
      await tester.pumpAndSettle();

      expect(service.deleteCalls, 1);
      expect(find.text('Vehículo eliminado'), findsOneWidget);
      final snackbar = tester.widget<SnackBar>(find.byType(SnackBar).last);
      expect(snackbar.backgroundColor, const Color(0xFF18181B));
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'desde el onboarding sin vehículos abre el formulario al cargar',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: darkTheme,
          home: VehiclesPage(
            vehiculoService: _FakeVehiculoService(),
            abrirFormularioInicial: true,
            marcaService: _FakeMarcaService(),
            modeloService: _FakeModeloService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Agregar Vehículo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('sin origen onboarding no abre el formulario automáticamente', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        home: VehiclesPage(
          vehiculoService: _FakeVehiculoService(),
          marcaService: _FakeMarcaService(),
          modeloService: _FakeModeloService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Agregar Vehículo'), findsNothing);
  });

  testWidgets('cancelar con datos pide confirmación antes de descartar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        home: VehiclesPage(
          vehiculoService: _FakeVehiculoService(),
          marcaService: _FakeMarcaService(),
          modeloService: _FakeModeloService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Agregar vehículo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), '2A4KM4A67GH');

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Descartar cambios?'), findsOneWidget);
    expect(
      find.text('Perderás los datos ingresados del vehículo.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Seguir editando'));
    await tester.pumpAndSettle();
    expect(find.text('Agregar Vehículo'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.text('Agregar Vehículo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el año se elige en orden descendente desde el año siguiente', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        home: VehiclesPage(
          vehiculoService: _FakeVehiculoService(),
          marcaService: _FakeMarcaService(),
          modeloService: _FakeModeloService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Agregar vehículo'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();

    final primero = '${DateTime.now().year + 1}';
    final segundo = '${DateTime.now().year}';
    expect(find.text(primero), findsOneWidget);
    expect(
      tester.getCenter(find.text(primero)).dy,
      lessThan(tester.getCenter(find.text(segundo)).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('el buscador de marca y modelo asigna la selección como chip', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        home: VehiclesPage(
          vehiculoService: _FakeVehiculoService(),
          marcaService: _FakeMarcaService(),
          modeloService: _FakeModeloService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Agregar vehículo'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'corol');
    await tester.pumpAndSettle();
    expect(find.text('Toyota • Corolla'), findsOneWidget);

    await tester.tap(find.text('Toyota • Corolla'));
    await tester.pumpAndSettle();
    expect(find.text('Toyota • Corolla'), findsOneWidget);
    expect(find.byTooltip('Cambiar marca y modelo'), findsOneWidget);

    await tester.tap(find.byTooltip('Cambiar marca y modelo'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Cambiar marca y modelo'), findsNothing);
    expect(find.text('Rango: 1900-${DateTime.now().year + 1}.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'la opción de solicitud abre el formulario para vehículos no listados',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: darkTheme,
          home: VehiclesPage(
            vehiculoService: _FakeVehiculoService(),
            marcaService: _FakeMarcaService(),
            modeloService: _FakeModeloService(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Agregar vehículo'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'xyz');
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Solicitar al administrador'));
      await tester.pumpAndSettle();

      expect(find.text('Solicitar vehículo'), findsOneWidget);
      expect(find.text('Enviar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('la tarjeta muestra la placa y al tocarla abre el VIN completo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final service = _FakeVehiculoService()
      ..vehicles = [
        {
          'id': 'vehicle-2',
          'vin': '1HGCM82633A004352',
          'placa': 'PBX-1234',
          'anio': 2022,
          'modelos_vehiculo': {
            'nombre': 'Corolla',
            'marcas_vehiculo': {'nombre': 'Toyota'},
          },
        },
      ];
    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        home: VehiclesPage(vehiculoService: service),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Placa: PBX-1234'), findsOneWidget);
    expect(find.text('VIN: ...004352'), findsOneWidget);
    expect(
      find.text('Solicitar repuesto para este vehículo →'),
      findsOneWidget,
    );

    await tester.tap(find.text('Toyota Corolla'));
    await tester.pumpAndSettle();

    expect(find.text('Detalle del vehículo'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText && widget.data == '1HGCM82633A004352',
      ),
      findsOneWidget,
    );
    expect(find.text('PBX-1234'), findsOneWidget);

    final portapapeles = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          portapapeles.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.tap(find.text('Copiar VIN'));
    await tester.pumpAndSettle();
    expect(portapapeles, ['1HGCM82633A004352']);
    expect(find.text('VIN copiado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeMarcaService extends MarcaService {
  @override
  Future<List<Map<String, dynamic>>> getMarcas() async => [
    {'id': 7, 'nombre': 'Toyota'},
  ];
}

class _FakeModeloService extends ModeloService {
  @override
  Future<List<Map<String, dynamic>>> getModelosPorMarca(int marcaId) async => [
    {'id': 11, 'nombre': 'Corolla', 'marca_id': 7},
  ];
}
