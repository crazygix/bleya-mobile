import 'package:dio/dio.dart';
import 'dart:io';

class _ApiUrls {
  static const String getProfile = '/users/me';
  static const String updateProfile = '/users/profile';
  static const String uploadProfileImage = '/users/profile-image';
  static String getUserById(String userId) => '/users/$userId';
}

class UserService {
  final Dio _dio;

  UserService(this._dio);

  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await _dio.get(_ApiUrls.getProfile);
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    String? username,
    String? bio,
  }) async {
    try {
      final response = await _dio.put(
        _ApiUrls.updateProfile,
        data: {
          if (username != null) 'username': username,
          if (bio != null) 'bio': bio,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> uploadProfileImage(File imageFile) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.path.split('/').last,
        ),
      });

      final response = await _dio.post(
        _ApiUrls.uploadProfileImage,
        data: formData,
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> getUserById(String userId) async {
    try {
      final response = await _dio.get(_ApiUrls.getUserById(userId));
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
        case 404:
          return Exception('User not found');
        default:
          return Exception('Server error: ${e.response?.statusCode}');
      }
    }
    return Exception('Network error: ${e.message}');
  }
}
