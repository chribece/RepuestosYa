import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:repuestosya/theme/app_colors.dart';
import 'package:repuestosya/widgets/ry_button.dart';

void main() {
  testWidgets(
    'variante whatsapp: fondo verde de marca y contenido (ícono + texto) centrado',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: RyButton(
                  label: 'Enviar WhatsApp',
                  iconWidget: FaIcon(FontAwesomeIcons.whatsapp),
                  variant: RyButtonVariant.whatsapp,
                  isFullWidth: true,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );

      final boton = tester.getRect(find.byType(RyButton));
      final icono = tester.getRect(find.byType(FaIcon));
      final texto = tester.getRect(find.text('Enviar WhatsApp'));
      final grupo = icono.expandToInclude(texto);

      expect(grupo.center.dx, closeTo(boton.center.dx, 1));
      expect(grupo.center.dy, closeTo(boton.center.dy, 1));

      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(RyButton),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, SemanticColors.colorWhatsApp);
    },
  );
}
