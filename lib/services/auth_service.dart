import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/app_errors.dart';

class _ApiUrls {
  static const String requestCode = '/auth/request-code';
  static const String verifyCode = '/auth/verify-code';
  static const String resendCode = '/auth/resend-code';
  static const String getMyInfo = '/auth/me';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String setUsername = '/auth/set-username';
}

class AuthService {
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  AuthService(this._dio, this._secureStorage);

  Future<Map<String, dynamic>> requestCode({required String phone}) async {
    try {
      final response = await _dio.post(
        _ApiUrls.requestCode,
        data: {'phoneNumber': phone},
      );
      // Don't log verification code in production
      if (kDebugMode) {
        print("Code sent: ${response.data["code"]}");
      }
      return {
        'codeSentAt': response.data['codeSentAt'] as String?,
      };
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Auth service error: $e');
      }
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> resendCode({required String phone}) async {
    try {
      final response = await _dio.post(
        _ApiUrls.resendCode,
        data: {'phoneNumber': phone},
      );
      // Don't log verification code in production
      if (kDebugMode) {
        print("Code resent: ${response.data["code"]}");
      }
      return {
        'codeSentAt': response.data['codeSentAt'] as String?,
      };
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> verifyCode(
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
      final bool requiresUsername = response.data['requiresUsername'] ?? false;
      // Persist token securely for subsequent sessions
      await _secureStorage.write(key: 'auth_token', value: token);
      return {
        'token': token,
        'requiresUsername': requiresUsername,
      };
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<void> setUsername({required String username}) async {
    try {
      await _dio.post(
        _ApiUrls.setUsername,
        data: {'username': username},
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> getMyInfo() async {
    try {
      final response = await _dio.get(_ApiUrls.getMyInfo);
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<String> refresh() async {
    try {
      // Cookies (httpOnly refreshToken) are sent by CookieManager
      // Mark as refresh to prevent interceptor from retrying on 401
      final response = await _dio.post(
        _ApiUrls.refresh,
        options: Options(
          extra: {'refresh': true},
        ),
      );
      final String token = response.data['token'];
      await _secureStorage.write(key: 'auth_token', value: token);
      return token;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post(
        _ApiUrls.logout,
        options: Options(
          extra: {'logout': true}, // Skip interceptor
        ),
      );
    } catch (_) {}
    await _secureStorage.delete(key: 'auth_token');
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
          userMessage = errorMessage; // Use backend message as user message
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
        case 403:
          return AppError(
            code: AppErrorCode.forbidden,
            message: errorMessage ?? 'Forbidden',
            userMessage: userMessage,
            originalError: e,
          );
        case 404:
          return NotFoundError(
            message: errorMessage ?? 'Resource not found',
            userMessage: userMessage,
            originalError: e,
          );
        case 409:
          return AppError(
            code: AppErrorCode.conflict,
            message: errorMessage ?? 'Conflict',
            userMessage: userMessage,
            originalError: e,
          );
        case 429:
          return TooManyRequestsError(
            message: errorMessage ?? 'Too many requests',
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
    
    // Handle network errors (no response)
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
