import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repuestosya/pages/register_cliente_page.dart';
import 'package:repuestosya/theme/app_theme.dart';
import 'package:repuestosya/widgets/ry_button.dart';

void main() {
  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: darkTheme, home: const RegisterClientePage()),
    );
    await tester.pump();
  }

  InkWell botonRegistrarse(WidgetTester tester) => tester.widget<InkWell>(
    find.descendant(
      of: find.widgetWithText(RyButton, 'Registrarse'),
      matching: find.byType(InkWell),
    ),
  );

  Future<void> llenarCampos(WidgetTester tester) async {
    final campos = find.byType(TextFormField);
    await tester.enterText(campos.at(0), 'Juan Pérez');
    await tester.enterText(campos.at(1), 'juan@correo.com');
    await tester.enterText(campos.at(2), '981894367');
    await tester.enterText(campos.at(3), '123456');
    await tester.enterText(campos.at(4), '123456');
    await tester.pump();
  }

  Future<void> tocarEnTextoPlano(
    WidgetTester tester,
    String fragmento,
    String buscado,
  ) async {
    final rich = find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText().contains(fragmento),
    );
    final render = tester.renderObject<RenderParagraph>(rich);
    final texto = render.text.toPlainText();
    final local = render.getOffsetForCaret(
      TextPosition(offset: texto.indexOf(buscado) + 2),
      Rect.zero,
    );
    await tester.tapAt(render.localToGlobal(local + const Offset(4, 9)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('Registrarse inicia deshabilitado', (tester) async {
    await pumpPage(tester);
    expect(botonRegistrarse(tester).onTap, isNull);
  });

  testWidgets('los campos no muestran asteriscos de obligatoriedad', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.textContaining('*'), findsNothing);
  });

  testWidgets('Registrarse se activa solo con campos llenos y términos', (
    tester,
  ) async {
    await pumpPage(tester);
    await llenarCampos(tester);
    expect(botonRegistrarse(tester).onTap, isNull, reason: 'falta aceptar');

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(botonRegistrarse(tester).onTap, isNotNull);
  });

  testWidgets('tocar Registrarse sin términos muestra el mensaje de error', (
    tester,
  ) async {
    await pumpPage(tester);
    await llenarCampos(tester);
    await tester.tap(find.text('Registrarse'));
    await tester.pump();

    expect(
      find.text('Debes aceptar los términos y condiciones para continuar.'),
      findsOneWidget,
    );
  });

  testWidgets('tocar el enlace de términos abre el modal sin marcar el box', (
    tester,
  ) async {
    await pumpPage(tester);
    await tocarEnTextoPlano(
      tester,
      'Acepto los términos',
      'términos y condiciones de uso',
    );

    expect(find.text('Términos y condiciones de uso'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
  });

  testWidgets(
    'con teclado abierto en "Confirmar contraseña", Registrarse queda visible',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(theme: darkTheme, home: const RegisterClientePage()),
      );
      await tester.pump();

      await tester.tap(find.byType(TextFormField).at(4));
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 400);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        tester.getBottomLeft(find.text('Registrarse')).dy,
        lessThanOrEqualTo(900 - 400),
        reason: 'El teclado tapa el botón Registrarse',
      );
    },
  );

  testWidgets('tocar el texto plano alterna el checkbox', (tester) async {
    await pumpPage(tester);
    await tocarEnTextoPlano(tester, 'Acepto los términos', 'Acepto');
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
  });
}
