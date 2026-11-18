import 'package:flutter_test/flutter_test.dart';

import 'package:repuestosya/providers/onboarding_provider.dart';
import 'package:repuestosya/services/onboarding_repository.dart';

class _FakeOnboardingRepository implements OnboardingRepository {
  _FakeOnboardingRepository({this.fail = false});

  final bool fail;

  @override
  Future<bool> isSkipped() async => false;

  @override
  Future<void> setSkipped() async {}

  @override
  Future<void> clearSkipped() async {}

  @override
  Future<bool> hasVehicle() async {
    if (fail) throw Exception('sin red');
    return true;
  }

  @override
  Future<bool> hasRequest() async => false;
}

void main() {
  test('isInitialized solo pasa a true al terminar la primera carga', () async {
    final provider = OnboardingProvider(
      repository: _FakeOnboardingRepository(),
    );
    addTearDown(provider.dispose);

    expect(provider.isInitialized, isFalse);

    final carga = provider.load();
    expect(provider.isLoading, isTrue);
    expect(provider.isInitialized, isFalse);

    await carga;
    expect(provider.isLoading, isFalse);
    expect(provider.isInitialized, isTrue);
    expect(provider.hasVehicle, isTrue);
  });

  test('una carga fallida también deja el estado inicializado', () async {
    final provider = OnboardingProvider(
      repository: _FakeOnboardingRepository(fail: true),
    );
    addTearDown(provider.dispose);

    await provider.load();

    expect(provider.isInitialized, isTrue);
    expect(provider.errorMessage, isNotNull);
  });
}
