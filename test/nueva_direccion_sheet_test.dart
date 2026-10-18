import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repuestosya/services/direccion_service.dart';
import 'package:repuestosya/services/geocoding_service.dart';
import 'package:repuestosya/services/ubicacion_service.dart';
import 'package:repuestosya/widgets/nueva_direccion_sheet.dart';
import 'package:repuestosya/widgets/ry_button.dart';

/// Pruebas del flujo UX del sheet "Nueva dirección": al usar el GPS o mover
/// el pin, el reverse geocoding prellena los campos en segundo plano, y las
/// ediciones del usuario no se pisan con autocompletados posteriores.
void main() {
  testWidgets('Guardar se habilita al completar alias y calle principal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NuevaDireccionSheet(
            direccionService: DireccionService(),
            resolverUbicacion: () async => const UbicacionResultado(
              estado: UbicacionEstado.noDisponible,
              mensaje: 'GPS no disponible',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final saveButtonFinder = find.widgetWithText(RyButton, 'Guardar');
    expect(tester.widget<RyButton>(saveButtonFinder).isDisabled, isTrue);

    await tester.enterText(find.byType(TextFormField).at(0), 'Casa');
    await tester.pump();
    expect(tester.widget<RyButton>(saveButtonFinder).isDisabled, isTrue);

    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Av. 10 de Agosto',
    );
    await tester.pump();

    final enabledSaveButton = tester.widget<RyButton>(saveButtonFinder);
    expect(enabledSaveButton.isDisabled, isFalse);
    expect(enabledSaveButton.variant, RyButtonVariant.primary);
    expect(tester.takeException(), isNull);
  });

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
    },
  );

  testWidgets('la edición del usuario no se pisa al mover el pin', (
    tester,
  ) async {
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
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Mi calle corregida',
    );
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

  testWidgets(
    'a tamaño de teléfono (360x690): los botones Cancelar/Guardar quedan '
    'SIEMPRE visibles al pie del sheet (no se recortan)',
    (tester) async {
      tester.view.physicalSize = const Size(360, 690);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Mismo patrón de apertura que create_request_page (showModalBottomSheet
      // con isScrollControlled).
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (sheetContext) => NuevaDireccionSheet(
                      direccionService: DireccionService(),
                      resolverUbicacion: () async =>
                          const UbicacionResultado.ok(-0.1913664, -78.4930512),
                    ),
                  );
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      // Los botones están en el árbol Y dentro de la pantalla (no recortados).
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);
      final rectGuardar = tester.getRect(find.text('Guardar'));
      expect(rectGuardar.bottom, lessThanOrEqualTo(690));
      final rectCancelar = tester.getRect(find.text('Cancelar'));
      expect(rectCancelar.bottom, lessThanOrEqualTo(690));

      // Son tocables sin necesidad de scrollear.
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Cancelar'), findsNothing); // el sheet se cerró
    },
  );

  testWidgets(
    'al mostrar el mapa GPS a 420px, Cancelar/Guardar quedan sobre el inset',
    (tester) async {
      const screenHeight = 900.0;
      const bottomInset = 24.0;
      tester.view.physicalSize = const Size(420, screenHeight);
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(bottom: bottomInset);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => NuevaDireccionSheet(
                    direccionService: DireccionService(),
                    resolverUbicacion: () async =>
                        const UbicacionResultado.ok(-0.1913664, -78.4930512),
                    geocodingService: _FakeGeocoding(),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usar mi ubicación actual'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();

      final cancelButton = find.ancestor(
        of: find.text('Cancelar'),
        matching: find.byType(RyButton),
      );
      final saveButton = find.ancestor(
        of: find.text('Guardar'),
        matching: find.byType(RyButton),
      );
      final cancelRect = tester.getRect(cancelButton);
      final saveRect = tester.getRect(saveButton);
      debugPrint(
        'GPS_SHEET cancel=$cancelRect save=$saveRect '
        'safeBottom=${screenHeight - bottomInset}',
      );
      expect(cancelRect.bottom, lessThanOrEqualTo(screenHeight - bottomInset));
      expect(saveRect.bottom, lessThanOrEqualTo(screenHeight - bottomInset));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'con el teclado abierto, las acciones quedan sobre el teclado y el inset',
    (tester) async {
      const screenHeight = 900.0;
      const keyboardInset = 280.0;
      const bottomInset = 24.0;
      tester.view.physicalSize = const Size(420, screenHeight);
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(bottom: bottomInset);
      tester.view.viewInsets = const FakeViewPadding(bottom: keyboardInset);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => NuevaDireccionSheet(
                    direccionService: DireccionService(),
                    resolverUbicacion: () async =>
                        const UbicacionResultado.ok(-0.1913664, -78.4930512),
                    geocodingService: _FakeGeocoding(),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usar mi ubicación actual'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();

      final cancelButton = find.ancestor(
        of: find.text('Cancelar'),
        matching: find.byType(RyButton),
      );
      final saveButton = find.ancestor(
        of: find.text('Guardar'),
        matching: find.byType(RyButton),
      );
      final cancelRect = tester.getRect(cancelButton);
      final saveRect = tester.getRect(saveButton);
      debugPrint(
        'GPS_SHEET_KEYBOARD cancel=$cancelRect save=$saveRect '
        'keyboardTop=${screenHeight - keyboardInset}',
      );
      expect(
        cancelRect.bottom,
        lessThanOrEqualTo(screenHeight - keyboardInset),
      );
      expect(saveRect.bottom, lessThanOrEqualTo(screenHeight - keyboardInset));
      expect(tester.takeException(), isNull);
    },
  );
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
