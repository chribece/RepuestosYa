import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets('éxito: muestra título y mensaje completos', (tester) async {
    await pumpYMostrar(
      tester,
      (context) => mostrarSnackbarExito(
        context,
        mensaje: 'Cotización aceptada correctamente',
      ),
    );

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byType(AwesomeSnackbarContent), findsOneWidget);
    expect(find.text('Éxito'), findsOneWidget);
    expect(find.text('Cotización aceptada correctamente'), findsOneWidget);
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
