import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:repuestosya/pages/onboarding_page.dart';
import 'package:repuestosya/providers/onboarding_provider.dart';
import 'package:repuestosya/router/route_names.dart';
import 'package:repuestosya/services/onboarding_repository.dart';
import 'package:repuestosya/widgets/ry_button.dart';

class _FakeOnboardingRepository implements OnboardingRepository {
  _FakeOnboardingRepository({bool hasVehicle = false, bool hasRequest = false})
    : _vehicleExists = hasVehicle,
      _requestExists = hasRequest;

  final bool _vehicleExists;
  final bool _requestExists;

  @override
  Future<bool> isSkipped() async => false;

  @override
  Future<void> setSkipped() async {}

  @override
  Future<void> clearSkipped() async {}

  @override
  Future<bool> hasVehicle() async => _vehicleExists;

  @override
  Future<bool> hasRequest() async => _requestExists;
}

void main() {
  Future<void> pumpOnboarding(
    WidgetTester tester, {
    bool hasVehicle = false,
    bool hasRequest = false,
  }) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final provider = OnboardingProvider(
      repository: _FakeOnboardingRepository(
        hasVehicle: hasVehicle,
        hasRequest: hasRequest,
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: OnboardingPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('resalta el paso activo y mantiene compactos los pasos '
      'pendientes', (tester) async {
    await pumpOnboarding(tester);

    expect(find.textContaining('Registrar tu vehículo'), findsOneWidget);
    expect(find.textContaining('Crear tu primera solicitud'), findsOneWidget);
    expect(
      find.text('Disponible al completar el paso anterior.'),
      findsOneWidget,
    );
    expect(find.text('Crear solicitud'), findsNothing);

    final vehicleButton = tester.widget<RyButton>(
      find.byWidgetPredicate(
        (widget) => widget is RyButton && widget.label == 'Registrar vehículo',
      ),
    );
    expect(vehicleButton.variant, RyButtonVariant.primary);
    expect(vehicleButton.isDisabled, isFalse);

    expect(find.text('Omitir'), findsOneWidget);
    expect(find.text('Omitir por ahora'), findsNothing);
    expect(find.text('PASO ACTUAL'), findsNothing);
    expect(find.text('PENDIENTE'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('habilita la primera solicitud al completar el paso del '
      'vehículo', (tester) async {
    await pumpOnboarding(tester, hasVehicle: true);

    expect(find.text('Tu vehículo ya está registrado.'), findsOneWidget);
    expect(find.text('Ver mis vehículos'), findsNothing);
    expect(find.text('Crear solicitud'), findsOneWidget);

    final requestButton = tester.widget<RyButton>(
      find.byWidgetPredicate(
        (widget) => widget is RyButton && widget.label == 'Crear solicitud',
      ),
    );
    expect(requestButton.isDisabled, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('al completar el onboarding ofrece Ir al inicio y navega a '
      'Home sin historial', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final provider = OnboardingProvider(
      repository: _FakeOnboardingRepository(hasVehicle: true, hasRequest: true),
    );
    addTearDown(provider.dispose);
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          name: RouteNames.onboarding,
          builder: (context, state) => const OnboardingPage(),
        ),
        GoRoute(
          path: '/home',
          name: RouteNames.home,
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('HOME_CLIENTE'))),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Omitir'), findsNothing);
    expect(find.text('Ir al inicio'), findsOneWidget);

    final homeButton = tester.widget<RyButton>(
      find.byWidgetPredicate(
        (widget) => widget is RyButton && widget.label == 'Ir al inicio',
      ),
    );
    expect(homeButton.variant, RyButtonVariant.primary);
    expect(homeButton.isFullWidth, isTrue);

    await tester.ensureVisible(find.text('Ir al inicio'));
    await tester.tap(find.text('Ir al inicio'));
    await tester.pumpAndSettle();

    expect(find.text('HOME_CLIENTE'), findsOneWidget);
    expect(router.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });
}
