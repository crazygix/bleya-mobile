enum Environment { dev, prod }

class EnvironmentConfig {
  static const String _defaultDevBaseUrl = 'http://192.168.1.4:8080/api/v1';
  static const String _defaultProdBaseUrl =
      'https://bleya.up.railway.app/api/v1';
  static const String _devBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL_DEV',
    defaultValue: _defaultDevBaseUrl,
  );
  static const String _prodBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL_PROD',
    defaultValue: _defaultProdBaseUrl,
  );

  static Environment _environment = Environment.dev;

  static Environment get environment => _environment;

  static void setEnvironment(Environment env) {
    _environment = env;
  }

  static String _resolveBaseUrl(String value, String fallback) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return fallback;
    }

    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  static String get baseUrl {
    switch (_environment) {
      case Environment.dev:
        return _resolveBaseUrl(_devBaseUrlOverride, _defaultDevBaseUrl);
      case Environment.prod:
        return _resolveBaseUrl(_prodBaseUrlOverride, _defaultProdBaseUrl);
    }
  }

  static String get environmentName {
    switch (_environment) {
      case Environment.dev:
        return 'Development';
      case Environment.prod:
        return 'Production';
    }
  }

  static bool get isDevelopment => _environment == Environment.dev;
  static bool get isProduction => _environment == Environment.prod;
}
