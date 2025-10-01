import 'package:dio/dio.dart';

class _ApiUrls {
  static const String requestCode = '/auth/request-code';
  static const String verifyCode = '/auth/verify-code';
  static const String getMyInfo = '/auth/me';
}

class AuthService {
  final Dio _dio;

  AuthService(this._dio);

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
      return response.data['token'];
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
