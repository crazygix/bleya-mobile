enum Environment { dev, prod }

class EnvironmentConfig {
  static Environment _environment = Environment.dev;

  static Environment get environment => _environment;

  static void setEnvironment(Environment env) {
    _environment = env;
  }

  static String get baseUrl {
    switch (_environment) {
      case Environment.dev:
        return 'http://localhost:8080/api';
      case Environment.prod:
        return 'https://bleya.up.railway.app/api';
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
