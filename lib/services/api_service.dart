import 'package:dio/dio.dart';

class ApiUrls {
  static const String baseUrl = 'http://localhost:8080/api';
  static const String requestCode = '/auth/request-code';
}

class ApiService {
  final Dio _dio = Dio(
      BaseOptions(baseUrl: ApiUrls.baseUrl, responseType: ResponseType.json));

  Future<String> requestCode({required String phone}) async {
    try {
      final response = await _dio.post(
        ApiUrls.requestCode,
        data: {'phoneNumber': phone},
      );
      print(response.data["code"].toString());
      return response.data["code"].toString();
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Exception _handleDioError(DioException e) {
    if (e.response != null) {
      // Handle specific status codes
      switch (e.response?.statusCode) {
        case 400:
          return Exception('Invalid request: ${e.response?.data}');
        case 429:
          return Exception('Too many attempts. Please try again later.');
        default:
          return Exception('Server error: ${e.response?.statusCode}');
      }
    }
    return Exception('Network error: ${e.message}');
  }
}
