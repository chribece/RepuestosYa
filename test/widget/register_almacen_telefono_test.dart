import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repuestosya/pages/register_almacen_page.dart';

void main() {
  testWidgets(
    'registro de almacén muestra aclaraciones y errores de contraseña en móvil',
    (tester) async {
      tester.view.physicalSize = const Size(360, 690);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: RegisterAlmacenPage()));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Nombre del local o responsable'), findsOneWidget);
      expect(find.text('Mínimo 6 caracteres.'), findsOneWidget);
      expect(
        find.text('Debe coincidir con la contraseña anterior.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField).at(0), 'Repuestos Juan');
      await tester.enterText(
        find.byType(TextField).at(1),
        'juan@repuestosya.com',
      );
      await tester.enterText(find.byType(TextField).at(2), '981234567');
      await tester.enterText(find.byType(TextField).at(3), '123');
      await tester.enterText(find.byType(TextField).at(4), '124');
      await tester.ensureVisible(find.text('CREAR CUENTA'));
      await tester.tap(find.text('CREAR CUENTA'));
      await tester.pump();

      expect(
        find.text('La contraseña debe tener al menos 6 caracteres'),
        findsOneWidget,
      );
      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('registro de almacén elimina cero inicial y muestra +593', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: RegisterAlmacenPage()));
    await tester.pump();

    final telefonoFinder = find.byType(TextField).at(2);
    await tester.enterText(telefonoFinder, '098123456');
    await tester.pump();

    final telefono = tester.widget<TextField>(telefonoFinder);
    expect(telefono.controller!.text, '98123456');
    expect(find.text('+593'), findsOneWidget);

    await tester.tap(find.text('CREAR CUENTA'));
    await tester.pump();

    expect(
      find.text('Ingresa 9 dígitos sin el 0, ej: 981894367'),
      findsOneWidget,
    );
  });

  testWidgets('registro de almacén exige nueve dígitos que comiencen con 9', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: RegisterAlmacenPage()));
    await tester.pump();

    await tester.enterText(find.byType(TextField).at(2), '98189436');
    await tester.tap(find.text('CREAR CUENTA'));
    await tester.pump();

    expect(
      find.text('Ingresa 9 dígitos sin el 0, ej: 981894367'),
      findsOneWidget,
    );
  });
}
