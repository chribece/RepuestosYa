import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repuestosya/pages/vehicles_page.dart';
import 'package:repuestosya/services/vehiculo_service.dart';
import 'package:repuestosya/widgets/ry_button.dart';

class _EmptyVehiculoService extends VehiculoService {
  @override
  Future<List<Map<String, dynamic>>> getVehiculos() async => [];
}

void main() {
  testWidgets('el estado vacío ofrece una acción principal para agregar '
      'el primer vehículo', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: VehiclesPage(vehiculoService: _EmptyVehiculoService())),
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
}
