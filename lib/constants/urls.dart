import '../config/environment.dart';

class ApiUrls {
  static String get baseUrl => EnvironmentConfig.apiBaseUrl;
}

class LegalUrls {
  static const String terms = 'https://bleyachat.com/terms';
  static const String privacy = 'https://bleyachat.com/privacy';
  static const String deleteAccount = 'https://bleyachat.com/delete-account';
}
