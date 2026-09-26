import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:repuestosya/widgets/ry_location_picker.dart';

/// Pruebas del selector visual de ubicación (RyLocationMapPicker):
/// verifica que mover el pin (tap-to-move o arrastre) actualiza las
/// coordenadas en vivo y que las finales son las del pin movido, no las
/// originales del GPS.
void main() {
  // Punto inicial típico del GPS en Quito (Iñaquito).
  const gpsInicial = LatLng(-0.1913664, -78.4930512);

  Widget pickerApp({
    required LatLng position,
    required ValueChanged<LatLng> onChanged,
    double width = 400,
    double height = 300,
    bool showPin = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            height: height,
            child: RyLocationMapPicker(
              initialPosition: position,
              onChanged: onChanged,
              showPin: showPin,
            ),
          ),
        ),
      ),
    );
  }

  Future<List<LatLng>> pumpPicker(
    WidgetTester tester, {
    double width = 400,
    double height = 300,
    LatLng? initialPosition,
    bool showPin = true,
  }) async {
    final movimientos = <LatLng>[];
    await tester.pumpWidget(
      pickerApp(
        position: initialPosition ?? gpsInicial,
        onChanged: movimientos.add,
        width: width,
        height: height,
        showPin: showPin,
      ),
    );
    await tester.pump();
    return movimientos;
  }

  testWidgets('tap-to-move: tocar el mapa mueve el pin y notifica', (
    tester,
  ) async {
    final movimientos = await pumpPicker(tester);

    // El mapa está centrado en el GPS inicial. Tocar la esquina superior
    // izquierda del mapa = punto al NOROESTE del centro: latitud mayor
    // (norte) y longitud menor (oeste).
    final mapTopLeft = tester.getTopLeft(find.byType(FlutterMap));
    await tester.tapAt(mapTopLeft + const Offset(60, 60));
    await tester.pump();

    expect(movimientos, isNotEmpty);
    final ultimo = movimientos.last;
    expect(ultimo.latitude, greaterThan(gpsInicial.latitude));
    expect(ultimo.longitude, lessThan(gpsInicial.longitude));
  });

  testWidgets(
    'cambio externo de posición (GPS resuelto): recentra el mapa en el '
    'punto sin notificar onChanged',
    (tester) async {
      final movimientos = await pumpPicker(tester);

      // El padre fija una nueva posición (simula GPS resuelto en otro punto).
      const nuevaPosicion = LatLng(-0.2401, -78.5100);
      await tester.pumpWidget(
        pickerApp(position: nuevaPosicion, onChanged: movimientos.add),
      );
      await tester.pump();

      // El movimiento fue programático: no se notificó onChanged.
      expect(movimientos, isEmpty);

      // La cámara se recentró en la NUEVA posición: tocar el centro del mapa
      // (que es donde queda el pin) debe devolver ≈ nuevaPosicion, no la vieja.
      await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
      await tester.pump();

      expect(movimientos, isNotEmpty);
      final punto = movimientos.last;
      expect(punto.latitude, closeTo(nuevaPosicion.latitude, 0.0002));
      expect(punto.longitude, closeTo(nuevaPosicion.longitude, 0.0002));
    },
  );

  testWidgets('showPin=false no muestra pin fantasma; aparece al fijar '
      'la ubicación', (tester) async {
    final movimientos = await pumpPicker(tester, showPin: false);

    // Sin ubicación fijada: no hay marcador visible.
    expect(find.byIcon(Icons.location_pin), findsNothing);

    // El padre fija la posición (GPS) → showPin=true → el pin aparece.
    const nuevaPosicion = LatLng(-0.2401, -78.5100);
    await tester.pumpWidget(
      pickerApp(
        position: nuevaPosicion,
        onChanged: movimientos.add,
        showPin: true,
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.location_pin), findsOneWidget);
    expect(movimientos, isEmpty);
  });

  testWidgets('el mapa se desplaza con un dedo (pan) sin mover el pin', (
    tester,
  ) async {
    final movimientos = await pumpPicker(tester);
    final posicionInicialPin = tester.getCenter(
      find.byIcon(Icons.location_pin),
    );

    // Arrastrar el mapa desde un punto lejos del marcador (esquina inferior
    // derecha, vacía) hacia arriba-izquierda: el mapa se desplaza y el pin
    // (punto geográfico fijo) cambia de posición en pantalla.
    final gesture = await tester.startGesture(
      tester.getBottomRight(find.byType(FlutterMap)) - const Offset(30, 30),
    );
    await gesture.moveBy(const Offset(-120, -80));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    final posicionFinalPin = tester.getCenter(find.byIcon(Icons.location_pin));
    expect(posicionFinalPin, isNot(posicionInicialPin));
    // El pan del mapa NO mueve el pin: no se disparó onChanged.
    expect(movimientos, isEmpty);
  });

  testWidgets(
    'arrastre del pin: las coordenadas finales son las del pin movido, '
    'no las del GPS original',
    (tester) async {
      final movimientos = await pumpPicker(tester);

      // Arrastrar el marcador con LONG-PRESS (mantener ~500ms y deslizar, el
      // patrón que funciona dentro de scroll views): 60px abajo y 80px a la
      // derecha → el pin se mueve al SURESTE (latitud menor, longitud mayor)
      // y se notifica en vivo.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.location_pin)),
      );
      await tester.pump(const Duration(milliseconds: 600)); // umbral long-press
      await gesture.moveBy(const Offset(20, 30));
      await tester.pump();
      await gesture.moveBy(const Offset(40, 50));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(movimientos, isNotEmpty);
      final ultimo = movimientos.last;
      expect(ultimo.latitude, lessThan(gpsInicial.latitude));
      expect(ultimo.longitude, greaterThan(gpsInicial.longitude));
    },
  );
}
