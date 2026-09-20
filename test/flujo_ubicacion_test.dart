import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repuestosya/services/ubicacion_service.dart';
import 'package:repuestosya/widgets/flujo_ubicacion.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pruebas del flujo GPS compartido (rationale previo → progreso →
/// Reintentar / ajustes según estado / manual), usado por el formulario de
/// solicitud y el perfil de almacén.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> confirmarRationale(WidgetTester tester) async {
    // El rationale aparece ANTES del popup nativo (solo la primera vez).
    expect(find.text('Permiso de ubicación'), findsOneWidget);
    await tester.tap(find.text('Entendido'));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('GPS ok: rationale → fijación, devuelve las coordenadas', (
    tester,
  ) async {
    final fake = _FakeUbicacion.secuencial([
      const UbicacionResultado.ok(-0.1913664, -78.4930512),
    ]);
    UbicacionResultado? resultado;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                resultado = await flujoUbicacionGps(context, fake);
              },
              child: const Text('iniciar'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('iniciar'));
    await tester.pump();
    await tester.pump();

    await confirmarRationale(tester);

    expect(fake.llamadas, 1);
    expect(resultado, isNotNull);
    expect(resultado!.disponible, isTrue);
    expect(resultado!.latitude, -0.1913664);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('rationale declinado ("Ahora no") → cancela sin pedir permiso', (
    tester,
  ) async {
    final fake = _FakeUbicacion.secuencial([
      const UbicacionResultado.ok(-0.1913664, -78.4930512),
    ]);
    UbicacionResultado? resultado;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                resultado = await flujoUbicacionGps(context, fake);
              },
              child: const Text('iniciar'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('iniciar'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Permiso de ubicación'), findsOneWidget);
    await tester.tap(find.text('Ahora no'));
    await tester.pump();
    await tester.pump();

    expect(resultado, isNotNull);
    expect(resultado!.estado, UbicacionEstado.cancelado);
    expect(resultado!.disponible, isFalse);
    // El servicio NO se invocó: no se disparó el permiso nativo.
    expect(fake.llamadas, 0);
  });

  testWidgets('GPS falla → opciones → Reintentar → ok', (tester) async {
    final fake = _FakeUbicacion.secuencial([
      const UbicacionResultado(
        estado: UbicacionEstado.noDisponible,
        mensaje: 'Sin señal GPS.',
      ),
      const UbicacionResultado.ok(-0.2201, -78.5128),
    ]);
    UbicacionResultado? resultado;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                resultado = await flujoUbicacionGps(context, fake);
              },
              child: const Text('iniciar'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('iniciar'));
    await tester.pump();
    await tester.pump();
    await confirmarRationale(tester);

    // Primer intento falló → diálogo de opciones visible (sin botón de
    // ajustes porque es un problema de señal, no de permiso/servicio).
    expect(find.text('No pudimos obtener tu ubicación'), findsOneWidget);
    expect(find.text('Abrir permisos de la app'), findsNothing);
    expect(find.text('Activar ubicación'), findsNothing);

    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(fake.llamadas, 2);
    expect(resultado, isNotNull);
    expect(resultado!.disponible, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('permiso denegado permanente → "Abrir permisos de la app"', (
    tester,
  ) async {
    final fake = _FakeUbicacion.secuencial([
      const UbicacionResultado(
        estado: UbicacionEstado.permisoDenegadoPermanente,
        mensaje: 'Permiso denegado permanentemente.',
      ),
    ]);
    UbicacionResultado? resultado;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                resultado = await flujoUbicacionGps(context, fake);
              },
              child: const Text('iniciar'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('iniciar'));
    await tester.pump();
    await tester.pump();
    await confirmarRationale(tester);

    // Permiso de la app bloqueado → botón que abre Ajustes de la app.
    expect(find.text('Abrir permisos de la app'), findsOneWidget);
    expect(find.text('Activar ubicación'), findsNothing);

    await tester.tap(find.text('Usar dirección manual'));
    await tester.pump();
    await tester.pump();

    expect(resultado, isNotNull);
    expect(resultado!.disponible, isFalse);
    expect(fake.llamadas, 1);
  });

  testWidgets('servicio GPS apagado → "Activar ubicación" (ajustes del '
      'sistema, no de la app)', (tester) async {
    final fake = _FakeUbicacion.secuencial([
      const UbicacionResultado(
        estado: UbicacionEstado.gpsApagado,
        mensaje: 'El GPS del dispositivo está apagado.',
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => flujoUbicacionGps(context, fake),
              child: const Text('iniciar'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('iniciar'));
    await tester.pump();
    await tester.pump();
    await confirmarRationale(tester);

    // Servicio del sistema apagado → botón que abre el interruptor del
    // sistema (openLocationSettings), distinto de los permisos de la app.
    expect(find.text('Activar ubicación'), findsOneWidget);
    expect(find.text('Abrir permisos de la app'), findsNothing);
  });
}

/// Fake de [UbicacionService]: devuelve resultados en secuencia y evita
/// llamadas a la plataforma (ajustes).
class _FakeUbicacion extends UbicacionService {
  _FakeUbicacion.secuencial(List<UbicacionResultado> resultados)
    : _resultados = List.of(resultados);

  final List<UbicacionResultado> _resultados;
  int llamadas = 0;
  int ajustesApp = 0;
  int ajustesSistema = 0;

  @override
  Future<UbicacionResultado> obtenerUbicacion({
    int intentos = UbicacionService.maxIntentos,
  }) async {
    llamadas++;
    if (_resultados.isEmpty) {
      return const UbicacionResultado(
        estado: UbicacionEstado.noDisponible,
        mensaje: 'Sin resultados en el fake',
      );
    }
    return _resultados.removeAt(0);
  }

  @override
  Future<bool> abrirAjustes() async {
    ajustesApp++;
    return true;
  }

  @override
  Future<bool> abrirAjustesSistema() async {
    ajustesSistema++;
    return true;
  }
}
