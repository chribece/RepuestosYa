import 'package:flutter_test/flutter_test.dart';

import 'package:repuestosya/config/app_config.dart';

void main() {
  tearDown(() {
    // Nunca dejar el override contaminando otros tests (estado global).
    AppConfig.aplicarOverrideParaTest(null, releaseMode: false);
  });

  test('prod con HTTP lanza StateError', () {
    final config = AppConfig.forTest('prod', 'http://x');

    expect(config.assertValidConfiguration, throwsA(isA<StateError>()));
  });

  test('staging con HTTP lanza StateError', () {
    final config = AppConfig.forTest('staging', 'http://x');

    expect(config.assertValidConfiguration, throwsA(isA<StateError>()));
  });

  test('prod con HTTPS es válido', () {
    final config = AppConfig.forTest('prod', 'https://x');

    expect(config.assertValidConfiguration, returnsNormally);
  });

  test('dev permite HTTP local', () {
    final config = AppConfig.forTest('dev', 'http://x');

    expect(config.assertValidConfiguration, returnsNormally);
  });

  test('overrideBaseUrl: en release el override es INERTE', () {
    final defaultBase = AppConfig.baseUrl;

    AppConfig.aplicarOverrideParaTest(
      'http://10.0.2.2:3000/api',
      releaseMode: true,
    );

    expect(
      AppConfig.overrideBaseUrl,
      isNull,
      reason: 'En release el override nunca se aplica',
    );
    expect(
      AppConfig.baseUrl,
      defaultBase,
      reason: 'La URL sigue siendo la de producción',
    );
  });

  test('overrideBaseUrl: en debug/profile se aplica (usado por el E2E)', () {
    AppConfig.aplicarOverrideParaTest(
      'http://192.168.100.2:3000/api',
      releaseMode: false,
    );

    expect(AppConfig.overrideBaseUrl, 'http://192.168.100.2:3000/api');
    expect(AppConfig.baseUrl, 'http://192.168.100.2:3000/api');
  });

  test('overrideBaseUrl: el setter público funciona en debug', () {
    AppConfig.overrideBaseUrl = 'http://192.168.100.2:3000/api';

    expect(AppConfig.baseUrl, 'http://192.168.100.2:3000/api');
  });
}
