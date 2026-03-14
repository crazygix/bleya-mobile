enum Environment { dev, prod }

class EnvironmentConfig {
  static const String _defaultDevApiBaseUrl = 'http://127.0.0.1:8080/v1';
  static const String _defaultProdApiBaseUrl = 'https://api.bleyachat.com/v1';
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
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

  static String _defaultApiBaseUrl(Environment environment) {
    switch (environment) {
      case Environment.dev:
        return _defaultDevApiBaseUrl;
      case Environment.prod:
        return _defaultProdApiBaseUrl;
    }
  }

  static String get apiBaseUrl {
    final fallback = _defaultApiBaseUrl(_environment);
    return _resolveBaseUrl(_apiBaseUrlOverride, fallback);
  }

  static String get socketBaseUrl {
    return apiBaseUrl.replaceFirst(
      RegExp(r'/v\d+$'),
      '',
    );
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
