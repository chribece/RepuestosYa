import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getwidget/getwidget.dart';
import 'package:provider/provider.dart';

import 'package:repuestosya/database/app_database.dart';
import 'package:repuestosya/pages/complete_profile_page.dart';
import 'package:repuestosya/services/auth_service.dart';
import 'package:repuestosya/services/almacen_repository.dart';
import 'package:repuestosya/services/geocoding_service.dart';
import 'package:repuestosya/theme/app_theme.dart';

class _GeocodingSinRed extends GeocodingService {
  @override
  Future<DireccionAutocompletada?> reverseGeocode({
    required double lat,
    required double lng,
    bool buscarCalleSecundariaCercana = false,
  }) async => null;

  @override
  Future<({double lat, double lng})?> buscarCentroCiudad(String ciudad) async =>
      null;
}

void main() {
  setUp(() {
    AuthService().currentUserForTesting = User(id: 'u-1', email: 'c@x.com');
  });

  tearDown(() {
    AuthService().currentUserForTesting = null;
  });

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      Provider<AlmacenRepository>.value(
        value: AlmacenRepository(db),
        child: MaterialApp(
          theme: darkTheme,
          home: CompleteProfilePage(geocodingService: _GeocodingSinRed()),
        ),
      ),
    );
    await tester.pump();
  }

  Finder campoRuc() => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == 'Ej: 1712345678001',
  );

  testWidgets('"Completar perfil" inicia deshabilitado', (tester) async {
    await pumpPage(tester);
    expect(find.text('Completar perfil'), findsOneWidget);
    expect(tester.widget<GFButton>(find.byType(GFButton)).onPressed, isNull);
  });

  testWidgets('los campos no muestran asteriscos de obligatoriedad', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.textContaining('*'), findsNothing);
  });

  testWidgets(
    'con teclado abierto en "Dirección", Completar perfil queda visible',
    (tester) async {
      await pumpPage(tester);
      final direccion = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText == 'Ej: De Los Jaribues, Marianitas',
      );
      await tester.ensureVisible(direccion);
      await tester.tap(direccion);
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 400);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        tester.getBottomLeft(find.text('Completar perfil')).dy,
        lessThanOrEqualTo(900 - 400),
        reason: 'El teclado tapa el botón Completar perfil',
      );
    },
  );

  testWidgets('un RUC inválido muestra el error bajo el campo', (tester) async {
    await pumpPage(tester);
    await tester.ensureVisible(campoRuc());
    await tester.enterText(campoRuc(), '3512345678901');
    await tester.pump();

    expect(
      find.text('El código de provincia del RUC no es válido'),
      findsOneWidget,
    );
  });
}
