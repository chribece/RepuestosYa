import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repuestosya/theme/app_colors.dart';
import 'package:repuestosya/utils/ry_snackbar.dart';

/// Pruebas del helper de notificaciones estilizadas (awesome_snackbar_content):
/// se muestra un SnackBar con el título y mensaje completos, y el tipo define
/// el ContentType (éxito/error/advertencia/info).
void main() {
  Future<void> pumpYMostrar(
    WidgetTester tester,
    void Function(BuildContext context) mostrar,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => mostrar(context),
              child: const Text('mostrar'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mostrar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
    'éxito: tarjeta oscura flotante con icono naranja y mensaje completo',
    (tester) async {
      await pumpYMostrar(
        tester,
        (context) => mostrarSnackbarExito(
          context,
          mensaje: 'Cotización aceptada correctamente',
        ),
      );

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.behavior, SnackBarBehavior.floating);
      expect(snackBar.backgroundColor, AppColors.surfaceContainerHigh);
      expect(find.byType(AwesomeSnackbarContent), findsNothing);
      expect(find.text('Cotización aceptada correctamente'), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle_rounded));
      expect(icon.color, AppColors.primaryContainer);
    },
  );

  testWidgets('éxito sobrio: usa el mismo estilo global de éxito', (
    tester,
  ) async {
    await pumpYMostrar(
      tester,
      (context) => mostrarSnackbarExitoSobrio(
        context,
        titulo: '¡Establecimiento Aprobado!',
        mensaje: 'Ya puedes recibir y responder solicitudes de cotización',
      ),
    );

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.backgroundColor, AppColors.surfaceContainerHigh);
    expect(find.text('¡Establecimiento Aprobado!'), findsOneWidget);
    expect(
      find.text('Ya puedes recibir y responder solicitudes de cotización'),
      findsOneWidget,
    );
    expect(find.byType(AwesomeSnackbarContent), findsNothing);
    final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle_rounded));
    expect(icon.color, AppColors.primaryContainer);
  });

  testWidgets('error: usa el tipo failure y conserva el mensaje', (
    tester,
  ) async {
    await pumpYMostrar(
      tester,
      (context) => mostrarSnackbarError(
        context,
        mensaje: 'No se pudo guardar tu teléfono. Verifica tu conexión.',
      ),
    );

    expect(find.text('Error'), findsOneWidget);
    expect(
      find.text('No se pudo guardar tu teléfono. Verifica tu conexión.'),
      findsOneWidget,
    );
    final awesome = tester.widget<AwesomeSnackbarContent>(
      find.byType(AwesomeSnackbarContent),
    );
    expect(awesome.contentType, ContentType.failure);
  });

  testWidgets('advertencia e info: títulos por defecto', (tester) async {
    await pumpYMostrar(
      tester,
      (context) => mostrarSnackbarAdvertencia(
        context,
        mensaje: 'Sin conexión. Se muestran los datos disponibles.',
      ),
    );
    expect(find.text('Aviso'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await pumpYMostrar(
      tester,
      (context) => mostrarSnackbarInfo(
        context,
        mensaje: '¡Has vuelto a tener conexión!',
      ),
    );
    expect(find.text('Información'), findsOneWidget);
  });
}
