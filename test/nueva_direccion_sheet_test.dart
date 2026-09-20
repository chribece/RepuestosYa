import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repuestosya/services/direccion_service.dart';
import 'package:repuestosya/services/geocoding_service.dart';
import 'package:repuestosya/services/ubicacion_service.dart';
import 'package:repuestosya/widgets/nueva_direccion_sheet.dart';

/// Pruebas del flujo UX del sheet "Nueva dirección": al usar el GPS o mover
/// el pin, el reverse geocoding prellena los campos en segundo plano, y las
/// ediciones del usuario no se pisan con autocompletados posteriores.
void main() {
  testWidgets(
      'usar el GPS autocompleta los campos y el usuario no reescribe desde cero',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fakeGeo = _FakeGeocoding();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NuevaDireccionSheet(
            direccionService: DireccionService(),
            resolverUbicacion: () async =>
                const UbicacionResultado.ok(-0.1913664, -78.4930512),
            geocodingService: fakeGeo,
          ),
        ),
      ),
    );

    // Antes del GPS no hay autocompletado.
    expect(find.text('Av. 10 de Agosto'), findsNothing);

    // Tocar "Usar mi ubicación actual": mapa + reverse geocoding (debounced).
    await tester.tap(find.text('Usar mi ubicación actual'));
    await tester.pump(); // setState: mapa visible
    await tester.pump(const Duration(milliseconds: 800)); // debounce
    await tester.pump(); // aplicar autocompletado

    expect(fakeGeo.llamadas, greaterThan(0));
    // Campos prellenados: calle principal y referencia.
    expect(find.text('Av. 10 de Agosto'), findsOneWidget);
    expect(find.text('La Pradera'), findsOneWidget);
  });

  testWidgets('la edición del usuario no se pisa al mover el pin',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fakeGeo = _FakeGeocoding();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NuevaDireccionSheet(
            direccionService: DireccionService(),
            resolverUbicacion: () async =>
                const UbicacionResultado.ok(-0.1913664, -78.4930512),
            geocodingService: fakeGeo,
          ),
        ),
      ),
    );

    // GPS → autocompletado inicial.
    await tester.tap(find.text('Usar mi ubicación actual'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(find.text('Av. 10 de Agosto'), findsOneWidget);

    // El usuario corrige la calle principal.
    await tester.enterText(find.byType(TextFormField).at(1), 'Mi calle corregida');
    await tester.pump();

    // Mover el pin (long-press + arrastre, el patrón que funciona dentro del
    // scroll view del sheet) dispara otro reverse geocoding…
    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.location_pin)),
    );
    await tester.pump(const Duration(milliseconds: 600)); // umbral long-press
    await gesture.moveBy(const Offset(40, 50));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    final llamadasAntes = fakeGeo.llamadas;
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();

    // …hubo un nuevo intento de autocompletado, pero NO pisó la edición.
    expect(fakeGeo.llamadas, greaterThan(llamadasAntes));
    expect(find.text('Mi calle corregida'), findsOneWidget);
    expect(find.text('Av. 10 de Agosto'), findsNothing);
  });
}

class _FakeGeocoding extends GeocodingService {
  int llamadas = 0;

  @override
  Future<DireccionAutocompletada?> reverseGeocode({
    required double lat,
    required double lng,
  }) async {
    llamadas++;
    return const DireccionAutocompletada(
      callePrincipal: 'Av. 10 de Agosto',
      referencia: 'La Pradera',
    );
  }
}
