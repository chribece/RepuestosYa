import 'package:flutter/foundation.dart';

/// Configuración de la aplicación por ambiente.
///
/// Los valores se leen mediante `String.fromEnvironment` y pueden
/// reemplazarse con `--dart-define` en cada build. Sin flags, los defaults
/// apuntan a PRODUCCIÓN: backend en Render (`https://repuestosya.onrender.com`)
/// y Supabase (mismo proyecto del desarrollo).
///
/// Desarrollo local (backend en la LAN):
/// `flutter run --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=http://192.168.100.2:3000/api`
///
/// Ejemplo:
/// `flutter run --dart-define=API_BASE_URL=https://api.repuestosya.com/api`
/// `--dart-define=APP_ENV=prod --dart-define=SUPABASE_URL=...`
/// `--dart-define=SUPABASE_ANON_KEY=...`
class AppConfig {
  AppConfig._();

  /// Backend de producción (Render). Se sobrescribe con `API_BASE_URL`.
  static const String _defaultApiBaseUrl =
      'https://repuestosya.onrender.com/api';
  static const String _defaultSupabaseUrl =
      'https://vpgnasrlgdgkxpggorxl.supabase.co';
  static const String _defaultSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZwZ25hc3JsZ2Rna3hwZ2dvcnhsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA4Njg0MzgsImV4cCI6MjA5NjQ0NDQzOH0.iENx5XVTyvr2-GLqOKqPzxwsekThJu1PNGDDpDfrOOE';

  static final String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultApiBaseUrl,
  );
  static final String _supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: _defaultSupabaseUrl,
  );
  static final String _supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: _defaultSupabaseAnonKey,
  );
  static final String _environment = _normalizedEnvironment(
    String.fromEnvironment('APP_ENV', defaultValue: 'prod'),
  );

  /// Permite al integration_test apuntar al backend LOCAL sin depender de
  /// `--dart-define` (en Flutter 3.44 no llegan al integration_test en
  /// dispositivos). Solo lo usa `integration_test/app_test.dart`.
  ///
  /// Protección de release: el setter es INERTE cuando `kReleaseMode == true`
  /// (compilado en `flutter build apk --release`), de modo que la app de
  /// producción SIEMPRE apunta a `API_BASE_URL` y nunca a una URL local.
  static set overrideBaseUrl(String? value) {
    aplicarOverrideParaTest(value, releaseMode: kReleaseMode);
  }

  static String? get overrideBaseUrl => _overrideBaseUrl;

  static String? _overrideBaseUrl;

  /// [visibleForTesting] — expone el guard del override para testear el
  /// comportamiento en release sin compilar en release (`kReleaseMode` es
  /// una constante de compilación y no se puede alternar en un test).
  @visibleForTesting
  static void aplicarOverrideParaTest(
    String? value, {
    required bool releaseMode,
  }) {
    if (releaseMode) return; // en release el override es inerte
    _overrideBaseUrl = value;
  }

  static String get baseUrl => _overrideBaseUrl ?? _baseUrl;
  static String get supabaseUrl => _supabaseUrl;
  static String get supabaseAnonKey => _supabaseAnonKey;
  static String get environment => _environment;

  /// Crea una configuración aislada para probar reglas de validación sin
  /// modificar los valores compilados de la aplicación.
  static AppConfigForTest forTest(String environment, String baseUrl) {
    return AppConfigForTest(environment, baseUrl);
  }

  static String _normalizedEnvironment(String value) {
    switch (value.toLowerCase()) {
      case 'staging':
        return 'staging';
      case 'prod':
        return 'prod';
      default:
        return 'dev';
    }
  }

  static void assertValidConfiguration() {
    if ((environment == 'prod' || environment == 'staging') &&
        !baseUrl.startsWith('https://')) {
      throw StateError(
        'Configuración inválida para $environment: API_BASE_URL debe usar HTTPS.',
      );
    }
  }
}

class AppConfigForTest {
  final String environment;
  final String baseUrl;

  const AppConfigForTest(this.environment, this.baseUrl);

  void assertValidConfiguration() {
    if ((environment == 'prod' || environment == 'staging') &&
        !baseUrl.startsWith('https://')) {
      throw StateError(
        'Configuración inválida para $environment: API_BASE_URL debe usar HTTPS.',
      );
    }
  }
}
