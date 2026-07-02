abstract final class AppConstants {
  static const String appName = 'GeoCampo';

  /*
    Configure el backend local con:
    flutter run --dart-define=API_BASE_URL=http://localhost:8001

    Valores comunes:
    - Chrome / Windows: http://localhost:8001
    - Android Emulator: http://10.0.2.2:8001
    - Celular fisico: http://IP_LOCAL_DE_TU_PC:8001
    - Produccion: usar --dart-define=API_BASE_URL=https://tu-dominio.com
  */
  static const String _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8001',
  );

  static const String apiPrefix = '/api';

  static String get apiBaseUrl => _withoutTrailingSlash(_apiBaseUrl);

  static String get apiUrl => '$apiBaseUrl$apiPrefix';

  static String _withoutTrailingSlash(String value) {
    if (value.endsWith('/')) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }
}
