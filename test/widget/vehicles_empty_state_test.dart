import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repuestosya/pages/vehicles_page.dart';
import 'package:repuestosya/services/vehiculo_service.dart';
import 'package:repuestosya/theme/app_colors.dart';
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
        Color.alphaBlend(
          AppColors.error.withValues(alpha: 0.32),
          AppColors.surfaceContainerHigh,
        ),
      );
      expect(
        destructiveButton.style!.foregroundColor!.resolve({}),
        SemanticColors.colorErrorText,
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
      expect(snackbar.backgroundColor, const Color(0xFF1E1E1E));
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
