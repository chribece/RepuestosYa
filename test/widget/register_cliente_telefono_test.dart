import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repuestosya/pages/register_cliente_page.dart';

/// Validación del registro de cliente: el TELÉFONO es obligatorio
/// (fundamental para la coordinación de entrega). Los casos se detienen en
/// la validación del formulario, sin tocar la red (AuthService no se invoca).
void main() {
  Future<void> pumpRegistro(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: RegisterClientePage()));
    await tester.pump();
  }

  Future<void> llenarCamposValidos(
    WidgetTester tester, {
    String? telefono,
  }) async {
    final campos = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(campos, hasLength(5));
    // Orden: nombre, email, teléfono, contraseña, confirmar contraseña.
    await tester.enterText(find.byType(TextField).at(0), 'Juan Pérez');
    await tester.enterText(find.byType(TextField).at(1), 'cliente@test.com');
    await tester.enterText(find.byType(TextField).at(2), telefono ?? '');
    await tester.enterText(find.byType(TextField).at(3), 'Clave-2026!');
    await tester.enterText(find.byType(TextField).at(4), 'Clave-2026!');
  }

  testWidgets('sin teléfono: el registro se bloquea con mensaje claro', (
    tester,
  ) async {
    await pumpRegistro(tester);
    await llenarCamposValidos(tester);

    await tester.tap(find.text('REGISTRARSE'));
    await tester.pump();

    expect(find.text('El teléfono es requerido'), findsOneWidget);
    // No hay SnackBar de red: la validación cortó antes del envío.
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('teléfono con menos de 9 dígitos: se bloquea', (tester) async {
    await pumpRegistro(tester);
    await llenarCamposValidos(tester, telefono: '0991234');

    await tester.tap(find.text('REGISTRARSE'));
    await tester.pump();

    expect(
      find.text('Ingresa un teléfono válido (mín. 9 dígitos)'),
      findsOneWidget,
    );
  });

  testWidgets('teléfono válido: la validación del formulario no muestra '
      'errores de teléfono', (tester) async {
    await pumpRegistro(tester);
    await llenarCamposValidos(tester, telefono: '+593 998757857');

    await tester.tap(find.text('REGISTRARSE'));
    await tester.pump();

    expect(find.text('El teléfono es requerido'), findsNothing);
    expect(
      find.text('Ingresa un teléfono válido (mín. 9 dígitos)'),
      findsNothing,
    );
    // En tests la red está bloqueada (respuesta 400) y el registro muestra
    // un SnackBar de error del servidor: se drena su temporizador para que
    // el test termine sin timers pendientes.
    await tester.pump(const Duration(seconds: 4));
  });
}
