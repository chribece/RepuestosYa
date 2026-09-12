/// Configuración de la aplicación por ambiente.
///
/// Los valores se leen mediante `String.fromEnvironment` y pueden
/// reemplazarse con `--dart-define` en cada build. Sin flags, se conservan
/// los valores de desarrollo actuales.
///
/// Ejemplo:
/// `flutter run --dart-define=API_BASE_URL=https://api.repuestosya.com/api`
/// `--dart-define=APP_ENV=prod --dart-define=SUPABASE_URL=...`
/// `--dart-define=SUPABASE_ANON_KEY=...`
class AppConfig {
  AppConfig._();

  static const String _defaultApiBaseUrl = 'http://192.168.100.2:3000/api';
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
    String.fromEnvironment('APP_ENV', defaultValue: 'dev'),
  );

  static String get baseUrl => _baseUrl;
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
