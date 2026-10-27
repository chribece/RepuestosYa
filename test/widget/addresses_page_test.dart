import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repuestosya/pages/addresses_page.dart';
import 'package:repuestosya/services/direccion_service.dart';
import 'package:repuestosya/services/geocoding_service.dart';
import 'package:repuestosya/services/ubicacion_service.dart';
import 'package:repuestosya/theme/app_colors.dart';
import 'package:repuestosya/theme/app_theme.dart';
import 'package:repuestosya/theme/app_spacing.dart';
import 'package:repuestosya/widgets/ry_button.dart';

class _FakeDireccionService extends DireccionService {
  List<Map<String, dynamic>> direcciones = [];
  final eliminadas = <String>[];
  Map<String, dynamic>? direccionCreada;
  Map<String, dynamic>? direccionActualizada;

  @override
  Future<List<Map<String, dynamic>>> getDirecciones() async =>
      List<Map<String, dynamic>>.from(direcciones);

  @override
  Future<void> deleteDireccion(String id) async {
    eliminadas.add(id);
    direcciones.removeWhere((direccion) => direccion['id'] == id);
  }

  @override
  Future<Map<String, dynamic>> createDireccion({
    required String alias,
    required String callePrincipal,
    String? ciudad,
    String? calleSecundaria,
    String? referencia,
    double? latitude,
    double? longitude,
    String? coordenadasFuente,
  }) async {
    direccionCreada = {
      'alias': alias,
      'ciudad': ciudad,
      'callePrincipal': callePrincipal,
      'calleSecundaria': calleSecundaria,
      'referencia': referencia,
      'latitude': latitude,
      'longitude': longitude,
      'coordenadasFuente': coordenadasFuente,
    };
    direcciones.add({
      'id': 'address-new',
      'alias': alias,
      'ciudad': ciudad,
      'calle_principal': callePrincipal,
    });
    return direccionCreada!;
  }

  @override
  Future<Map<String, dynamic>> updateDireccion({
    required String id,
    String? alias,
    String? callePrincipal,
    String? ciudad,
    String? calleSecundaria,
    String? referencia,
    double? latitude,
    double? longitude,
    String? coordenadasFuente,
  }) async {
    direccionActualizada = {
      'id': id,
      'alias': alias,
      'ciudad': ciudad,
      'callePrincipal': callePrincipal,
      'calleSecundaria': calleSecundaria,
      'referencia': referencia,
      'latitude': latitude,
      'longitude': longitude,
      'coordenadasFuente': coordenadasFuente,
    };
    return direccionActualizada!;
  }
}

class _FakeGeocodingService extends GeocodingService {
  DireccionAutocompletada? reverseResult;

  @override
  Future<DireccionAutocompletada?> reverseGeocode({
    required double lat,
    required double lng,
    bool buscarCalleSecundariaCercana = false,
  }) async => reverseResult;
}

void main() {
  testWidgets(
    'confirmación elimina la dirección por alias con estilo oscuro y botones en línea',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final service = _FakeDireccionService()
        ..direcciones = [
          {
            'id': 'address-home',
            'alias': 'Casa',
            'calle_principal': 'Av. Amazonas',
            'ciudad': 'Quito',
          },
          {
            'id': 'address-work',
            'alias': 'Trabajo',
            'calle_principal': 'Av. República',
            'ciudad': 'Quito',
          },
          {
            'id': 'address-other',
            'alias': 'Familiar',
            'calle_principal': 'Calle 10',
            'ciudad': 'Quito',
          },
        ];

      await tester.pumpWidget(
        MaterialApp(
          theme: darkTheme,
          home: AddressesPage(direccionService: service),
        ),
      );
      await tester.pumpAndSettle();

      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(
        (listView.padding! as EdgeInsets).bottom,
        greaterThanOrEqualTo(100),
      );

      await tester.tap(find.byTooltip('Eliminar dirección').first);
      await tester.pumpAndSettle();

      expect(find.text('Eliminar dirección'), findsOneWidget);
      expect(
        find.text(
          "¿Estás seguro de que deseas eliminar la dirección 'Casa'? "
          'Esta acción no se puede deshacer.',
        ),
        findsOneWidget,
      );

      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.backgroundColor, const Color(0xFF1E1E1E));
      expect(dialog.shape, isA<RoundedRectangleBorder>());

      final cancelar = find.widgetWithText(OutlinedButton, 'Cancelar');
      final eliminar = find.widgetWithText(TextButton, 'Eliminar');
      expect(cancelar, findsOneWidget);
      expect(eliminar, findsOneWidget);
      expect(
        tester.getRect(find.text('Cancelar')).top,
        closeTo(tester.getRect(find.text('Eliminar').last).top, 1),
      );

      final botonEliminar = tester.widget<TextButton>(eliminar);
      expect(
        botonEliminar.style!.backgroundColor!.resolve({}),
        Color.alphaBlend(
          AppColors.error.withValues(alpha: 0.32),
          AppColors.surfaceContainerHigh,
        ),
      );

      await tester.tap(cancelar);
      await tester.pumpAndSettle();
      expect(service.eliminadas, isEmpty);

      await tester.tap(find.byTooltip('Eliminar dirección').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
      await tester.pumpAndSettle();

      expect(service.eliminadas, ['address-home']);
      expect(find.text('Casa'), findsNothing);
      expect(find.text('Dirección eliminada correctamente'), findsOneWidget);
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar).last).backgroundColor,
        const Color(0xFF1E1E1E),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('GPS obtiene coordenadas y prellena ciudad y calle', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final service = _FakeDireccionService();
    final geocoding = _FakeGeocodingService()
      ..reverseResult = const DireccionAutocompletada(
        ciudad: 'Quito',
        callePrincipal: 'Av. Amazonas',
        calleSecundaria: 'Calle transversal',
        referencia: 'La Carolina',
      );
    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        home: AddressesPage(
          direccionService: service,
          geocodingService: geocoding,
          resolverUbicacion: () async =>
              const UbicacionResultado.ok(-0.18, -78.47),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Ubicación (GPS)'), findsOneWidget);
    final gpsButton = tester.widget<RyButton>(
      find.widgetWithText(RyButton, 'Mi ubicación actual'),
    );
    expect(gpsButton.isFullWidth, isTrue);
    expect(gpsButton.horizontalPadding, AppSpacing.spacingMd);
    await tester.tap(find.text('Mi ubicación actual'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    expect(
      tester.widget<TextFormField>(fields.at(1)).controller!.text,
      'Quito',
    );
    expect(
      tester.widget<TextFormField>(fields.at(2)).controller!.text,
      'Av. Amazonas',
    );
    expect(
      tester.widget<TextFormField>(fields.at(3)).controller!.text,
      'Calle transversal',
    );
    expect(
      tester.widget<TextFormField>(fields.at(4)).controller!.text,
      'La Carolina',
    );
    await tester.tap(find.text('Confirmar ubicación'));
    await tester.pumpAndSettle();
    await tester.enterText(fields.at(0), 'Casa');
    await tester.pump();
    expect(tester.widget<TextFormField>(fields.at(0)).controller!.text, 'Casa');
    expect(
      tester.widget<TextFormField>(fields.at(2)).controller!.text,
      'Av. Amazonas',
    );
    expect(
      tester
          .widget<RyButton>(find.widgetWithText(RyButton, 'Guardar'))
          .isDisabled,
      isFalse,
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(service.direccionCreada, isNotNull);
    expect(service.direccionCreada?['ciudad'], 'Quito');
    expect(service.direccionCreada?['latitude'], -0.18);
    expect(service.direccionCreada?['longitude'], -78.47);
    expect(service.direccionCreada?['coordenadasFuente'], 'gps');
  });

  testWidgets('el guardado manual requiere que el usuario indique ciudad', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final service = _FakeDireccionService();
    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        home: AddressesPage(direccionService: service),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Casa');
    await tester.enterText(fields.at(2), 'Av. Amazonas');
    await tester.pump();
    expect(find.text('Agregar nueva dirección'), findsOneWidget);
    expect(
      tester
          .widget<RyButton>(find.widgetWithText(RyButton, 'Guardar'))
          .isDisabled,
      isTrue,
    );
    await tester.enterText(fields.at(1), 'Quito');
    await tester.pump();
    expect(
      tester
          .widget<RyButton>(find.widgetWithText(RyButton, 'Guardar'))
          .isDisabled,
      isFalse,
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(service.direccionCreada?['ciudad'], 'Quito');
    expect(service.direccionCreada?['latitude'], isNull);
    expect(service.direccionCreada?['longitude'], isNull);
  });

  testWidgets('editar dirección permite ajustar y guardar el pin en el mapa', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final service = _FakeDireccionService()
      ..direcciones = [
        {
          'id': 'address-home',
          'alias': 'Casa',
          'ciudad': 'Quito',
          'calle_principal': 'Av. Amazonas',
          'latitude': -0.18,
          'longitude': -78.47,
          'coordenadas_fuente': 'gps',
        },
      ];
    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        home: AddressesPage(
          direccionService: service,
          geocodingService: _FakeGeocodingService(),
          resolverUbicacion: () async =>
              const UbicacionResultado.ok(-0.18, -78.47),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Editar dirección'));
    await tester.pumpAndSettle();

    expect(find.text('Editar dirección'), findsOneWidget);
    expect(find.text('Confirmar ubicación'), findsOneWidget);
    await tester.tap(find.text('Confirmar ubicación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(service.direccionActualizada?['id'], 'address-home');
    expect(service.direccionActualizada?['latitude'], -0.18);
    expect(service.direccionActualizada?['longitude'], -78.47);
    expect(service.direccionActualizada?['coordenadasFuente'], 'gps');
  });
}
