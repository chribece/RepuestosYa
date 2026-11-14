import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repuestosya/utils/ry_snackbar.dart';

/// Pruebas del helper de notificaciones: diseño oscuro unificado con un
/// acento semántico por tipo (ícono, borde y contenedor del ícono).
void main() {
  const fondo = Color(0xFF18181B);
  const exito = Color(0xFF22C55E);
  const error = Color(0xFFEF4444);
  const aviso = Color(0xFFF59E0B);
  const info = Color(0xFF38BDF8);

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

  Color iconoColor(WidgetTester tester, IconData icono) =>
      tester.widget<Icon>(find.byIcon(icono)).color!;

  testWidgets('éxito: tarjeta oscura flotante con acento esmeralda', (
    tester,
  ) async {
    await pumpYMostrar(
      tester,
      (context) => mostrarSnackbarExito(
        context,
        mensaje: 'Cotización aceptada correctamente',
      ),
    );

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.behavior, SnackBarBehavior.floating);
    expect(snackBar.backgroundColor, fondo);
    expect(
      (snackBar.shape! as RoundedRectangleBorder).side.color,
      exito.withValues(alpha: 0.35),
    );
    expect(find.text('Cotización aceptada correctamente'), findsOneWidget);
    expect(iconoColor(tester, Icons.check_circle_outline_rounded), exito);
  });

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
    expect(snackBar.backgroundColor, fondo);
    expect(find.text('¡Establecimiento Aprobado!'), findsOneWidget);
    expect(
      find.text('Ya puedes recibir y responder solicitudes de cotización'),
      findsOneWidget,
    );
    expect(iconoColor(tester, Icons.check_circle_outline_rounded), exito);
  });

  testWidgets('error: acento coral con título por defecto y mensaje completo', (
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
    expect(iconoColor(tester, Icons.error_outline_rounded), error);
  });

  testWidgets('advertencia e info: títulos y acentos por defecto', (
    tester,
  ) async {
    await pumpYMostrar(
      tester,
      (context) => mostrarSnackbarAdvertencia(
        context,
        mensaje: 'Sin conexión. Se muestran los datos disponibles.',
      ),
    );
    expect(find.text('Aviso'), findsOneWidget);
    expect(iconoColor(tester, Icons.warning_amber_rounded), aviso);

    await tester.pumpWidget(const SizedBox());
    await pumpYMostrar(
      tester,
      (context) => mostrarSnackbarInfo(
        context,
        mensaje: '¡Has vuelto a tener conexión!',
      ),
    );
    expect(find.text('Información'), findsOneWidget);
    expect(iconoColor(tester, Icons.info_outline_rounded), info);
  });

  testWidgets('sin conexión: acento coral con ícono wifi tachado y cierre', (
    tester,
  ) async {
    await pumpYMostrar(
      tester,
      (context) => mostrarSnackbarSinConexion(
        context,
        mensaje: 'No pudimos actualizar. Desliza para reintentar.',
      ),
    );

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.showCloseIcon, isTrue);
    expect(snackBar.backgroundColor, fondo);
    expect(iconoColor(tester, Icons.wifi_off_rounded), error);
    expect(
      find.text('No pudimos actualizar. Desliza para reintentar.'),
      findsOneWidget,
    );
  });
}
