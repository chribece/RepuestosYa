import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getwidget/getwidget.dart';
import 'package:provider/provider.dart';

import 'package:repuestosya/pages/addresses_page.dart';
import 'package:repuestosya/pages/onboarding_page.dart';
import 'package:repuestosya/pages/register_cliente_page.dart';
import 'package:repuestosya/pages/vehicles_page.dart';
import 'package:repuestosya/providers/onboarding_provider.dart';
import 'package:repuestosya/services/marca_service.dart';
import 'package:repuestosya/services/modelo_service.dart';
import 'package:repuestosya/services/onboarding_repository.dart';
import 'package:repuestosya/theme/app_colors.dart';
import 'package:repuestosya/theme/app_text_styles.dart';
import 'package:repuestosya/theme/app_theme.dart';
import 'package:repuestosya/widgets/ry_button.dart';

void main() {
  const registrationLink = '¿Ya tienes cuenta? Inicia sesión';
  const onboardingTitle = 'Comienza con RepuestosYa';
  const vinError = 'VIN inválido: 17 caracteres, sin I, O ni Q.';
  const vinHelper = '17 caracteres; sin I, O ni Q.';
  final latestAllowedYear = DateTime.now().year + 1;
  final yearRangeHint = 'Rango: 1900-$latestAllowedYear.';
  final yearRangeMessage = 'Ingresa un año entre 1900 y $latestAllowedYear.';

  Future<void> setViewport(
    WidgetTester tester, {
    required double width,
    double height = 900,
    double bottomInset = 0,
    double keyboardInset = 0,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = FakeViewPadding(bottom: bottomInset);
    tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
    tester.platformDispatcher.textScaleFactorTestValue = 1;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  testWidgets('el enlace de registro se lee completo a 420 y 800 px', (
    tester,
  ) async {
    for (final width in [420.0, 800.0]) {
      await setViewport(tester, width: width);
      await tester.pumpWidget(
        MaterialApp(theme: darkTheme, home: const RegisterClientePage()),
      );
      await tester.pump();

      final finder = find.text(registrationLink);
      expect(finder, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(finder);
      final available = paragraph.constraints.maxWidth;
      final intrinsic = paragraph.getMaxIntrinsicWidth(double.infinity);
      final measured = TextPainter(
        text: TextSpan(
          text: registrationLink,
          style: AppTextStyles.textStyleButton,
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
      )..layout(maxWidth: available);
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      debugPrint(
        'REGISTER width=$width intrinsic-before=${intrinsic.toStringAsFixed(1)} '
        'available=${available.toStringAsFixed(1)} '
        'measuredLines=${measured.computeLineMetrics().length} '
        'measuredWidth=${measured.width.toStringAsFixed(1)} '
        'measuredDidExceed=${measured.didExceedMaxLines} '
        'didExceedMaxLines=${paragraph.didExceedMaxLines} '
        'rect=${tester.getRect(finder)}',
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(
        measured.computeLineMetrics().every((line) => line.width <= available),
        isTrue,
      );
      expect(measured.didExceedMaxLines, isFalse);
      expect(tester.getRect(finder).left, greaterThanOrEqualTo(0));
      expect(tester.getRect(finder).right, lessThanOrEqualTo(width));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('RyButton mantiene alturas táctiles y sólidos a 420 px', (
    tester,
  ) async {
    await setViewport(tester, width: 420);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              RyButton(
                key: ValueKey('link-button'),
                label: registrationLink,
                variant: RyButtonVariant.text,
                isFullWidth: true,
              ),
              RyButton(
                key: ValueKey('solid-button'),
                label: 'Continuar',
                variant: RyButtonVariant.primary,
                size: RyButtonSize.large,
                isFullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('link-button'))).height,
      48,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('solid-button'))).height,
      56,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('el título de onboarding se lee completo a 420 y 800 px', (
    tester,
  ) async {
    for (final width in [420.0, 800.0]) {
      await setViewport(tester, width: width);
      final provider = OnboardingProvider(
        repository: _FakeOnboardingRepository(),
      );
      addTearDown(provider.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<OnboardingProvider>.value(
          value: provider,
          child: MaterialApp(
            theme: darkTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const OnboardingPage(),
                      ),
                    ),
                    child: const Text('Ir al onboarding'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ir al onboarding'));
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.pump();

      final finder = find.text(onboardingTitle);
      expect(finder, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(finder);
      final available = paragraph.constraints.maxWidth;
      final intrinsic = paragraph.getMaxIntrinsicWidth(double.infinity);
      final painter = TextPainter(
        text: TextSpan(
          text: onboardingTitle,
          style: AppTextStyles.textStyleCaption,
        ),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
        maxLines: 2,
      )..layout(maxWidth: available);
      final originalTitlePainter = TextPainter(
        text: TextSpan(
          text: onboardingTitle,
          style: AppTextStyles.textStyleTitle,
        ),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
        maxLines: 1,
      )..layout(maxWidth: available);
      debugPrint(
        'ONBOARDING width=$width intrinsic=${intrinsic.toStringAsFixed(1)} '
        'originalTitleWidth='
        '${originalTitlePainter.maxIntrinsicWidth.toStringAsFixed(1)} '
        'originalDidExceed=${originalTitlePainter.didExceedMaxLines} '
        'manualTextWidth=${painter.width.toStringAsFixed(1)} '
        'available=${available.toStringAsFixed(1)} '
        'measuredLines=${painter.computeLineMetrics().length} '
        'measuredDidExceed=${painter.didExceedMaxLines} '
        'maxLines=${paragraph.maxLines} '
        'overflow=${paragraph.overflow} '
        'didExceedMaxLines=${paragraph.didExceedMaxLines} '
        'rect=${tester.getRect(finder)}',
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(
        painter.computeLineMetrics().every((line) => line.width <= available),
        isTrue,
      );
      expect(painter.didExceedMaxLines, isFalse);
      if (width == 420) {
        expect(originalTitlePainter.didExceedMaxLines, isTrue);
      }
      final titleRect = tester.getRect(finder);
      final appBarRect = tester.getRect(find.byType(AppBar));
      final appBarFinder = find.byType(AppBar);
      final actionFinder = find.descendant(
        of: appBarFinder,
        matching: find.byType(RyButton),
      );
      expect(actionFinder, findsOneWidget);
      final actionRect = tester.getRect(actionFinder);
      final leadingFinder = find.descendant(
        of: appBarFinder,
        matching: find.byType(BackButton),
      );
      expect(leadingFinder, findsOneWidget);
      debugPrint(
        'ONBOARDING_CHROME width=$width leading=${tester.getRect(leadingFinder)} '
        'actions=1 actionRect=$actionRect '
        'titleTextStyle=${AppTextStyles.textStyleCaption.fontSize}',
      );
      if (width == 420) {
        expect(titleRect.height, greaterThan(24));
        expect(titleRect.right, lessThanOrEqualTo(actionRect.left));
      }
      expect(titleRect.bottom, lessThanOrEqualTo(appBarRect.bottom));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('las acciones de dirección respetan inset y teclado a 420 px', (
    tester,
  ) async {
    const inset = 24.0;
    await setViewport(
      tester,
      width: 420,
      bottomInset: inset,
      keyboardInset: 280,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const AddressDialog(),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    final panel = tester.getRect(
      find.byKey(const ValueKey('ry-form-dialog-panel')),
    );
    final cancelRect = tester.getRect(find.text('Cancelar'));
    final saveRect = tester.getRect(find.text('Guardar'));
    const safeBottom = 900 - inset - 280;
    debugPrint(
      'ADDRESS panel=$panel height=${panel.height.toStringAsFixed(1)} '
      'cancel=$cancelRect save=$saveRect '
      'safeBottom=$safeBottom '
      'saveGap=${(safeBottom - saveRect.bottom).toStringAsFixed(1)}',
    );
    expect(panel.height, lessThan(900 - 280));
    expect(panel.bottom, lessThanOrEqualTo(safeBottom));
    expect(cancelRect.bottom, lessThanOrEqualTo(safeBottom));
    expect(saveRect.bottom, lessThanOrEqualTo(safeBottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('el diálogo conserva un ancho cómodo a 800 px', (tester) async {
    await setViewport(tester, width: 800, height: 1200, bottomInset: 24);
    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const AddressDialog(),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    final panel = tester.getRect(
      find.byKey(const ValueKey('ry-form-dialog-panel')),
    );
    final saveRect = tester.getRect(find.text('Guardar'));
    expect(panel.width, lessThanOrEqualTo(560));
    expect(panel.height, lessThan(1200));
    expect(saveRect.bottom, lessThanOrEqualTo(1200 - 24));
    expect(tester.takeException(), isNull);
  });

  testWidgets('las acciones del diálogo quedan sobre el inset a 420 px', (
    tester,
  ) async {
    const screenHeight = 900.0;
    const bottomInset = 24.0;
    await setViewport(
      tester,
      width: 420,
      height: screenHeight,
      bottomInset: bottomInset,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const AddressDialog(),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    final panel = tester.getRect(
      find.byKey(const ValueKey('ry-form-dialog-panel')),
    );
    final cancelRect = tester.getRect(find.text('Cancelar'));
    final saveRect = tester.getRect(find.text('Guardar'));
    final safeBottom = screenHeight - bottomInset;
    debugPrint(
      'ADDRESS_NO_KEYBOARD panel=$panel cancel=$cancelRect save=$saveRect '
      'safeBottom=$safeBottom '
      'saveGap=${(safeBottom - saveRect.bottom).toStringAsFixed(1)}',
    );
    expect(panel.bottom, lessThanOrEqualTo(safeBottom));
    expect(cancelRect.bottom, lessThanOrEqualTo(safeBottom));
    expect(saveRect.bottom, lessThanOrEqualTo(safeBottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('edición de vehículo conserva marca y modelo disponibles', (
    tester,
  ) async {
    await setViewport(tester, width: 420);
    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        home: Scaffold(
          body: VehicleFormDialog(
            vehiculo: {
              'id': 'vehicle-1',
              'vin': '1HGCM82633A004352',
              'anio': 2020,
              'modelos_vehiculo': {
                'id': 11,
                'nombre': 'Corolla',
                'marca_id': 7,
                'marcas_vehiculo': {'id': 7, 'nombre': 'Toyota'},
              },
            },
            onSave: () {},
            marcaService: _FakeMarcaService(),
            modeloService: _FakeModeloService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Toyota'), findsOneWidget);
    expect(find.text('Corolla'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('modelo obsoleto al editar muestra el selector vacío sin error', (
    tester,
  ) async {
    await setViewport(tester, width: 420);
    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        home: Scaffold(
          body: VehicleFormDialog(
            vehiculo: {
              'id': 'vehicle-1',
              'vin': '1HGCM82633A004352',
              'anio': 2020,
              'modelos_vehiculo': {
                'id': 99,
                'nombre': 'Modelo retirado',
                'marca_id': 7,
                'marcas_vehiculo': {'id': 7, 'nombre': 'Toyota'},
              },
            },
            onSave: () {},
            marcaService: _FakeMarcaService(),
            modeloService: _FakeModeloService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Toyota'), findsOneWidget);
    expect(find.text('Selecciona un modelo'), findsOneWidget);
    expect(find.text('Modelo retirado'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Guardar permanece deshabilitado mientras falten campos obligatorios',
    (tester) async {
      await setViewport(tester, width: 420);
      await tester.pumpWidget(
        MaterialApp(
          theme: darkTheme,
          home: Scaffold(
            body: VehicleFormDialog(
              onSave: () {},
              marcaService: _FakeMarcaService(),
              modeloService: _FakeModeloService(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final saveButton = tester.widget<RyButton>(
        find.widgetWithText(RyButton, 'Guardar'),
      );
      expect(saveButton.onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Guardar se habilita con marca, modelo, VIN y año válidos', (
    tester,
  ) async {
    await setViewport(tester, width: 420);
    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        home: Scaffold(
          body: VehicleFormDialog(
            onSave: () {},
            marcaService: _FakeMarcaService(),
            modeloService: _FakeModeloService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final marcaDropdown = tester.widget<GFDropdown<int>>(
      find.byType(GFDropdown<int>).at(0),
    );
    marcaDropdown.onChanged!(7);
    await tester.pumpAndSettle();

    final modeloDropdown = tester.widget<GFDropdown<int>>(
      find.byType(GFDropdown<int>).at(1),
    );
    modeloDropdown.onChanged!(11);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      '2A4KM4A67GH123456',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      DateTime.now().year.toString(),
    );
    await tester.pumpAndSettle();

    final saveButton = tester.widget<RyButton>(
      find.widgetWithText(RyButton, 'Guardar'),
    );
    expect(saveButton.onPressed, isNotNull);
    expect(saveButton.variant, RyButtonVariant.primary);
    expect(tester.takeException(), isNull);
  });

  testWidgets('las ayudas del formulario de vehículo hacen wrap a 420 px', (
    tester,
  ) async {
    await setViewport(tester, width: 420);
    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        home: Scaffold(
          body: VehicleFormDialog(
            onSave: () {},
            marcaService: _FakeMarcaService(),
            modeloService: _FakeModeloService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final vinCounter = find.text('0/17');
    expect(vinCounter, findsOneWidget);
    expect(
      tester.widget<Text>(vinCounter).style?.color,
      AppColors.onSurfaceVariant.withValues(alpha: 0.75),
    );

    for (final helper in [vinHelper, yearRangeHint]) {
      final finder = find.text(helper);
      expect(finder, findsOneWidget);
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      final paragraph = tester.renderObject<RenderParagraph>(finder);
      final helperRect = tester.getRect(finder);
      final scrollRect = tester.getRect(
        find.byKey(const ValueKey('ry-form-dialog-scroll')),
      );
      expect(helperRect.top, greaterThanOrEqualTo(scrollRect.top));
      expect(helperRect.bottom, lessThanOrEqualTo(scrollRect.bottom));
      expect(paragraph.didExceedMaxLines, isFalse, reason: helper);
    }
    expect(find.text('Ej: ABC-1234'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).keyboardType,
      TextInputType.number,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('VIN acepta caracteres alfanuméricos y limita la entrada a 17', (
    tester,
  ) async {
    await setViewport(tester, width: 420);
    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        home: Scaffold(
          body: VehicleFormDialog(
            onSave: () {},
            marcaService: _FakeMarcaService(),
            modeloService: _FakeModeloService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final vinField = find.byType(TextFormField).at(0);
    await tester.enterText(vinField, '2a4km4a67gh123456ZZ');

    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
      '2A4KM4A67GH123456',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('VIN corto y año fuera de rango muestran errores a 420 px', (
    tester,
  ) async {
    await setViewport(tester, width: 420);
    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        home: Scaffold(
          body: VehicleFormDialog(
            onSave: () {},
            marcaService: _FakeMarcaService(),
            modeloService: _FakeModeloService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '123');
    await tester.enterText(find.byType(TextFormField).at(1), '1800');
    await tester.enterText(find.byType(TextFormField).at(2), 'ABC-12');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text(vinError), findsOneWidget);
    expect(find.text(yearRangeMessage), findsOneWidget);
    expect(find.text('Usa 3 letras y 3-4 números.'), findsOneWidget);
    for (final message in [
      vinError,
      yearRangeMessage,
      'Usa 3 letras y 3-4 números.',
    ]) {
      expect(
        tester
            .renderObject<RenderParagraph>(find.text(message))
            .didExceedMaxLines,
        isFalse,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('dirección y ciudad requeridas muestran errores a 420 px', (
    tester,
  ) async {
    await setViewport(tester, width: 420);
    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const AddressDialog(),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    expect(dialog.backgroundColor, const Color(0xFF1E1E1E));
    final cancelButton = find.widgetWithText(RyButton, 'Cancelar');
    final saveButton = find.widgetWithText(RyButton, 'Guardar');
    expect(
      tester.getRect(cancelButton).top,
      closeTo(tester.getRect(saveButton).top, 1),
    );

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller!
          .text,
      '',
    );
    for (final message in [
      'El alias debe tener al menos 2 caracteres',
      'La ciudad es obligatoria',
      'La calle principal debe tener al menos 5 caracteres',
    ]) {
      expect(find.text(message), findsOneWidget);
      final finder = find.text(message);
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      final paragraph = tester.renderObject<RenderParagraph>(finder);
      final messageRect = tester.getRect(finder);
      final scrollRect = tester.getRect(
        find.byKey(const ValueKey('ry-form-dialog-scroll')),
      );
      expect(messageRect.top, greaterThanOrEqualTo(scrollRect.top));
      expect(messageRect.bottom, lessThanOrEqualTo(scrollRect.bottom));
      expect(paragraph.didExceedMaxLines, isFalse, reason: message);
    }
    expect(tester.takeException(), isNull);
  });
}

class _FakeOnboardingRepository implements OnboardingRepository {
  @override
  Future<bool> isSkipped() async => false;

  @override
  Future<void> setSkipped() async {}

  @override
  Future<void> clearSkipped() async {}

  @override
  Future<bool> hasVehicle() async => false;

  @override
  Future<bool> hasRequest() async => false;
}

class _FakeMarcaService extends MarcaService {
  @override
  Future<List<Map<String, dynamic>>> getMarcas() async => [
    {'id': 7, 'nombre': 'Toyota'},
  ];
}

class _FakeModeloService extends ModeloService {
  @override
  Future<List<Map<String, dynamic>>> getModelosPorMarca(int marcaId) async =>
      marcaId == 7
      ? [
          {'id': 11, 'nombre': 'Corolla', 'marca_id': 7},
        ]
      : [];
}
