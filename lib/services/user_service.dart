import 'package:dio/dio.dart';
import 'dart:io';
import '../utils/app_errors.dart';

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

  AppError _handleDioError(DioException e) {
    if (e.response != null) {
      final statusCode = e.response?.statusCode;
      final responseData = e.response?.data;
      
      // Try to extract error message from backend response
      String? errorMessage;
      String? userMessage;
      Map<String, dynamic>? details;
      
      if (responseData is Map<String, dynamic> && responseData['error'] != null) {
        final errorData = responseData['error'];
        if (errorData is Map<String, dynamic>) {
          errorMessage = errorData['message'] as String?;
          userMessage = errorMessage;
          details = errorData['details'] as Map<String, dynamic>?;
        }
      }
      
      switch (statusCode) {
        case 400:
          return BadRequestError(
            message: errorMessage ?? 'Invalid request',
            userMessage: userMessage,
            details: details,
            originalError: e,
          );
        case 401:
          return UnauthorizedError(
            message: errorMessage ?? 'Unauthorized',
            userMessage: userMessage,
            originalError: e,
          );
        case 404:
          return NotFoundError(
            message: errorMessage ?? 'User not found',
            userMessage: userMessage,
            originalError: e,
          );
        case 500:
        case 502:
        case 503:
        case 504:
          return ServerError(
            message: errorMessage ?? 'Server error',
            userMessage: userMessage,
            originalError: e,
          );
        default:
          return ServerError(
            message: errorMessage ?? 'Server error: $statusCode',
            userMessage: userMessage,
            originalError: e,
          );
      }
    }
    
    // Handle network errors
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return AppError(
        code: AppErrorCode.connectionTimeout,
        message: 'Connection timeout',
        userMessage: 'Request timed out. Please check your connection and try again.',
        originalError: e,
      );
    }
    
    if (e.type == DioExceptionType.connectionError) {
      return NetworkError(
        message: 'Network connection error',
        userMessage: 'Unable to connect to the server. Please check your internet connection.',
        originalError: e,
      );
    }
    
    return NetworkError(
      message: e.message ?? 'Network error',
      originalError: e,
    );
  }
}
