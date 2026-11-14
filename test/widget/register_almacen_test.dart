import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repuestosya/pages/register_almacen_page.dart';
import 'package:repuestosya/theme/app_theme.dart';
import 'package:repuestosya/widgets/ry_button.dart';

void main() {
  Future<void> pumpPage(WidgetTester tester, {double height = 900}) async {
    tester.view.physicalSize = Size(420, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: darkTheme, home: const RegisterAlmacenPage()),
    );
    await tester.pump();
  }

  InkWell botonContinuar(WidgetTester tester) => tester.widget<InkWell>(
    find.descendant(
      of: find.widgetWithText(RyButton, 'Continuar'),
      matching: find.byType(InkWell),
    ),
  );

  Future<void> llenarCampos(WidgetTester tester) async {
    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'Repuestos Don Juan');
    await tester.enterText(campos.at(1), 'contacto@donjuan.com');
    await tester.enterText(campos.at(2), '981894367');
    await tester.enterText(campos.at(3), '123456');
    await tester.enterText(campos.at(4), '123456');
    await tester.pump();
  }

  testWidgets('Continuar inicia deshabilitado', (tester) async {
    await pumpPage(tester);
    expect(botonContinuar(tester).onTap, isNull);
  });

  testWidgets('los campos no muestran asteriscos de obligatoriedad', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.textContaining('*'), findsNothing);
  });

  testWidgets('Continuar se activa solo con todos los campos completos', (
    tester,
  ) async {
    await pumpPage(tester);
    await llenarCampos(tester);
    expect(botonContinuar(tester).onTap, isNotNull);
  });

  testWidgets('los datos del paso 1 se conservan al volver a la pantalla', (
    tester,
  ) async {
    await pumpPage(tester);
    await llenarCampos(tester);

    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester);

    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
      'Repuestos Don Juan',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
      'contacto@donjuan.com',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text,
      '981894367',
    );
  });

  testWidgets(
    'con teclado abierto en "Confirmar contraseña", Continuar queda visible',
    (tester) async {
      await pumpPage(tester);
      await llenarCampos(tester);

      await tester.tap(find.byType(TextFormField).at(4));
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 400);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        tester.getBottomLeft(find.text('Continuar')).dy,
        lessThanOrEqualTo(900 - 400),
        reason: 'El teclado tapa el botón Continuar',
      );
    },
  );
}
