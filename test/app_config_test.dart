import 'package:flutter_test/flutter_test.dart';

import 'package:repuestosya/config/app_config.dart';

void main() {
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
}
