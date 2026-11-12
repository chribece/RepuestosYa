import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repuestosya/pages/role_selection_page.dart';
import 'package:repuestosya/theme/app_theme.dart';
import 'package:repuestosya/widgets/ry_button.dart';

void main() {
  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: darkTheme, home: const RoleSelectionPage()),
    );
    await tester.pump();
  }

  InkWell botonContinuar(WidgetTester tester) => tester.widget<InkWell>(
    find.descendant(of: find.byType(RyButton), matching: find.byType(InkWell)),
  );

  Future<void> tocarBordeTarjeta(WidgetTester tester, String rol) async {
    final tarjeta = find.ancestor(
      of: find.text(rol),
      matching: find.byType(InkWell),
    );
    final rect = tester.getRect(tarjeta);
    await tester.tapAt(Offset(rect.left + 12, rect.center.dy));
    await tester.pump();
  }

  testWidgets('Continuar inicia deshabilitado sin rol seleccionado', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(botonContinuar(tester).onTap, isNull);
  });

  testWidgets('tocar Continuar sin rol muestra el mensaje de validación', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.text('Selecciona una opción para continuar.'), findsNothing);

    await tester.tap(find.text('Continuar'));
    await tester.pump();

    expect(find.text('Selecciona una opción para continuar.'), findsOneWidget);
  });

  testWidgets('tocar el borde de la tarjeta Cliente la selecciona', (
    tester,
  ) async {
    await pumpPage(tester);
    await tocarBordeTarjeta(tester, 'Cliente');

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(botonContinuar(tester).onTap, isNotNull);
    expect(find.text('Selecciona una opción para continuar.'), findsNothing);
  });

  testWidgets('tocar el borde de la tarjeta Almacén la selecciona', (
    tester,
  ) async {
    await pumpPage(tester);
    await tocarBordeTarjeta(tester, 'Almacén');

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(botonContinuar(tester).onTap, isNotNull);
  });
}
