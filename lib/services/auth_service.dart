import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class _ApiUrls {
  static const String requestCode = '/auth/request-code';
  static const String verifyCode = '/auth/verify-code';
  static const String getMyInfo = '/auth/me';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
}

class AuthService {
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  AuthService(this._dio, this._secureStorage);

  Future<void> requestCode({required String phone}) async {
    try {
      final response = await _dio.post(
        _ApiUrls.requestCode,
        data: {'phoneNumber': phone},
      );
      print("Code sent: ${response.data["code"]}");
    } on DioException catch (e) {
      print(e);
      throw _handleDioError(e);
    }
  }

  Future<String> verifyCode(
      {required String phone, required String code}) async {
    try {
      final response = await _dio.post(
        _ApiUrls.verifyCode,
        data: {
          'phoneNumber': phone,
          'code': code,
        },
      );
      final String token = response.data['token'];
      // Persist token securely for subsequent sessions
      await _secureStorage.write(key: 'auth_token', value: token);
      return token;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> getMyInfo({required String token}) async {
    try {
      final response = await _dio.get(
        _ApiUrls.getMyInfo,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<String> refresh() async {
    try {
      // Cookies (httpOnly refreshToken) are sent by CookieManager
      final response = await _dio.post(_ApiUrls.refresh);
      final String token = response.data['token'];
      await _secureStorage.write(key: 'auth_token', value: token);
      return token;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post(_ApiUrls.logout);
    } catch (_) {}
    await _secureStorage.delete(key: 'auth_token');
  }

  Exception _handleDioError(DioException e) {
    if (e.response != null) {
      switch (e.response?.statusCode) {
        case 400:
          return Exception('Invalid request: ${e.response?.data}');
        case 401:
          return Exception('Unauthorized');
        case 429:
          return Exception('Too many attempts. Please try again later.');
        default:
          return Exception('Server error: ${e.response?.statusCode}');
      }
    }
    return Exception('Network error: ${e.message}');
  }
}
