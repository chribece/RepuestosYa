import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repuestosya/pages/welcome_page.dart';

void main() {
  testWidgets('WelcomePage muestra la identidad y acciones principales', (
    WidgetTester tester,
  ) async {
    // Se reemplaza el smoke test del contador de Flutter porque no pertenece
    // al producto y dependía de un widget raíz inexistente en RepuestosYa.
    // WelcomePage se puede construir aislada: las rutas solo se ejecutan al
    // pulsar los botones, por lo que este smoke test no usa red ni plugins.
    await tester.pumpWidget(const MaterialApp(home: WelcomePage()));

    expect(find.text('RepuestosYa'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Crear nueva cuenta'), findsOneWidget);
  });
}
