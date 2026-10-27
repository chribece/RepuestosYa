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
  testWidgets('Guardar requiere alias, ciudad y calle principal', (
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
      find.byType(TextFormField).at(2),
      'Av. 10 de Agosto',
    );
    await tester.pump();
    expect(tester.widget<RyButton>(saveButtonFinder).isDisabled, isTrue);

    await tester.enterText(find.byType(TextFormField).at(1), 'Quito');
    await tester.pump();

    final enabledSaveButton = tester.widget<RyButton>(saveButtonFinder);
    expect(enabledSaveButton.isDisabled, isFalse);
    expect(enabledSaveButton.variant, RyButtonVariant.primary);
    expect(tester.takeException(), isNull);
  });

  testWidgets('si GPS no detecta una ciudad, se exige ingreso manual', (
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
            resolverUbicacion: () async =>
                const UbicacionResultado.ok(-0.18, -78.47),
            geocodingService: _FakeGeocodingSinCiudad(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mi ubicación actual'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump();

    final fields = find.byType(TextFormField);
    expect(tester.widget<TextFormField>(fields.at(1)).controller!.text, '');
    await tester.enterText(fields.at(0), 'Casa');
    await tester.enterText(fields.at(2), 'Av. Amazonas');
    await tester.pump();
    final saveButton = find.widgetWithText(RyButton, 'Guardar');
    expect(tester.widget<RyButton>(saveButton).isDisabled, isTrue);

    await tester.enterText(fields.at(1), 'Quito');
    await tester.pump();
    expect(tester.widget<RyButton>(saveButton).isDisabled, isFalse);
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

      // Tocar "Mi ubicación actual": mapa + reverse geocoding (debounced).
      await tester.tap(find.text('Mi ubicación actual'));
      await tester.pump(); // setState: mapa visible
      await tester.pump(const Duration(milliseconds: 1100)); // debounce
      await tester.pump(); // aplicar autocompletado

      expect(fakeGeo.llamadas, greaterThan(0));
      // Campos prellenados: calle principal y referencia.
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        'Quito',
      );
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
    await tester.tap(find.text('Mi ubicación actual'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump();
    expect(find.text('Av. 10 de Agosto'), findsOneWidget);

    // El usuario corrige la calle principal.
    await tester.enterText(
      find.byType(TextFormField).at(2),
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
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump();

    // …hubo un nuevo intento de autocompletado, pero NO pisó la edición.
    expect(fakeGeo.llamadas, greaterThan(llamadasAntes));
    expect(find.text('Mi calle corregida'), findsOneWidget);
    expect(find.text('Av. 10 de Agosto'), findsNothing);
  });

  testWidgets('confirmar el pin solicita y rellena la vía transversal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
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

    await tester.tap(find.text('Mi ubicación actual'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump();
    expect(fakeGeo.busquedasDeCruce, [true]);

    await tester.tap(find.text('Confirmar ubicación'));
    await tester.pumpAndSettle();

    expect(fakeGeo.busquedasDeCruce, [true, true]);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(3))
          .controller!
          .text,
      'Calle transversal',
    );
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
      await tester.tap(find.text('Mi ubicación actual'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
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
      await tester.tap(find.text('Mi ubicación actual'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
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

  testWidgets('el título del sheet respeta el área segura superior', (
    tester,
  ) async {
    const topInset = 28.0;
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(top: topInset, bottom: 24);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => NuevaDireccionSheet(
                  direccionService: DireccionService(),
                  resolverUbicacion: () async => const UbicacionResultado(
                    estado: UbicacionEstado.noDisponible,
                  ),
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

    expect(find.text('Agregar nueva dirección'), findsOneWidget);
    expect(
      tester.getRect(find.text('Agregar nueva dirección')).top,
      greaterThanOrEqualTo(topInset),
    );
    expect(tester.takeException(), isNull);
  });
}

class _FakeGeocoding extends GeocodingService {
  int llamadas = 0;
  final busquedasDeCruce = <bool>[];

  @override
  Future<DireccionAutocompletada?> reverseGeocode({
    required double lat,
    required double lng,
    bool buscarCalleSecundariaCercana = false,
  }) async {
    llamadas++;
    busquedasDeCruce.add(buscarCalleSecundariaCercana);
    return DireccionAutocompletada(
      ciudad: 'Quito',
      callePrincipal: 'Av. 10 de Agosto',
      calleSecundaria: buscarCalleSecundariaCercana
          ? 'Calle transversal'
          : null,
      referencia: 'La Pradera',
    );
  }
}

class _FakeGeocodingSinCiudad extends GeocodingService {
  @override
  Future<DireccionAutocompletada?> reverseGeocode({
    required double lat,
    required double lng,
    bool buscarCalleSecundariaCercana = false,
  }) async {
    return const DireccionAutocompletada(
      callePrincipal: 'Av. Amazonas',
      calleSecundaria: 'Calle transversal',
    );
  }
}
