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
    await tocarEnTextoPlano(tester, 'Acepto los términos', 'términos de uso');

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

  Future<void> pumpEn(
    WidgetTester tester,
    Size size, {
    double escala = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(escala)),
          child: child!,
        ),
        home: const RegisterClientePage(),
      ),
    );
    await tester.pump();
  }

  double extensionDeScroll(WidgetTester tester) => tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .maxScrollExtent;

  testWidgets('360x800 y 412x915: el formulario cabe sin scroll en reposo', (
    tester,
  ) async {
    for (final size in const [Size(360, 800), Size(412, 915)]) {
      await pumpEn(tester, size);
      expect(tester.takeException(), isNull, reason: '$size');
      expect(extensionDeScroll(tester), 0, reason: '$size');
      expect(find.text('Registrarse'), findsOneWidget);
    }
  });

  testWidgets('360x640: la página se desplaza sin desbordamientos', (
    tester,
  ) async {
    await pumpEn(tester, const Size(360, 640));
    expect(tester.takeException(), isNull);
    expect(extensionDeScroll(tester), greaterThan(0));
  });

  testWidgets('escala de texto 1.3: sin excepciones de layout', (tester) async {
    await pumpEn(tester, const Size(360, 800), escala: 1.3);
    expect(tester.takeException(), isNull);
    expect(find.text('Registro de Cliente'), findsOneWidget);
    expect(find.text('+593'), findsOneWidget);
  });

  testWidgets('la fortaleza de la contraseña aparece y refleja el nivel', (
    tester,
  ) async {
    await pumpEn(tester, const Size(412, 915));
    expect(find.text('Débil'), findsNothing);

    await tester.enterText(find.byType(TextFormField).at(3), 'abc');
    await tester.pump();
    expect(find.text('Débil'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(3), 'abcdefg1');
    await tester.pump();
    expect(find.text('Fuerte'), findsOneWidget);
  });

  testWidgets('el prefijo +593 queda a 14 px del borde izquierdo y centrado', (
    tester,
  ) async {
    await pumpEn(tester, const Size(412, 915));
    final xIcono = tester.getTopLeft(find.byIcon(Icons.mail)).dx;
    final xPrefijo = tester
        .getTopLeft(
          find
              .ancestor(of: find.text('+593'), matching: find.byType(Container))
              .first,
        )
        .dx;
    expect(xPrefijo - xIcono, closeTo(14, 0.5));
    final pildora = find
        .ancestor(of: find.text('+593'), matching: find.byType(Container))
        .first;
    final campo = find.ancestor(
      of: find.text('+593'),
      matching: find.byType(TextFormField),
    );
    final centroCampo = tester.getCenter(
      find.descendant(of: campo, matching: find.byType(EditableText)),
    );
    expect(tester.getCenter(pildora).dy, closeTo(centroCampo.dy, 4));
  });

  testWidgets('el borde enfocado de los campos es naranja de 1.5 px', (
    tester,
  ) async {
    await pumpEn(tester, const Size(412, 915));
    await tester.tap(find.byType(TextFormField).first);
    await tester.pump();
    final borde =
        Theme.of(
              tester.element(find.byType(Form)),
            ).inputDecorationTheme.focusedBorder!
            as OutlineInputBorder;
    expect(borde.borderSide.color, darkTheme.colorScheme.primaryContainer);
    expect(borde.borderSide.width, 1.5);
  });

  testWidgets(
    'el texto de términos no deja una palabra sola en la última línea',
    (tester) async {
      await pumpEn(tester, const Size(360, 800));
      final finder = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('Acepto los'),
      );
      final render = tester.renderObject<RenderParagraph>(finder);
      final texto = render.text.toPlainText();
      final dyDe = render
          .getOffsetForCaret(
            TextPosition(offset: texto.indexOf(' de ') + 1),
            Rect.zero,
          )
          .dy;
      final dyUso = render
          .getOffsetForCaret(
            TextPosition(offset: texto.indexOf('uso')),
            Rect.zero,
          )
          .dy;
      expect(dyUso, dyDe, reason: 'uso debe compartir línea con de');
    },
  );

  testWidgets('tocar el texto plano alterna el checkbox', (tester) async {
    await pumpPage(tester);
    await tocarEnTextoPlano(tester, 'Acepto los términos', 'Acepto');
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
  });
}
