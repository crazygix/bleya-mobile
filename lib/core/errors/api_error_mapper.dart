import 'package:dio/dio.dart';
import '../../utils/app_errors.dart';

class ApiErrorMapper {
  static AppError mapDioError(DioException e) {
    if (e.response != null) {
      final statusCode = e.response?.statusCode;
      final responseData = e.response?.data;

      String? errorMessage;
      String? userMessage;
      Map<String, dynamic>? details;

      if (responseData is Map && responseData['error'] != null) {
        final errorData = responseData['error'];
        if (errorData is Map) {
          // Tolerate unexpected shapes (e.g. `details` as a list) rather than
          // throwing a cast error in place of the real API error.
          final rawMessage = errorData['message'];
          errorMessage = rawMessage is String ? rawMessage : null;
          userMessage = errorMessage;
          final rawDetails = errorData['details'];
          details =
              rawDetails is Map ? Map<String, dynamic>.from(rawDetails) : null;
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

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return AppError(
        code: AppErrorCode.connectionTimeout,
        message: 'Connection timeout',
        userMessage:
            'Request timed out. Please check your connection and try again.',
        originalError: e,
      );
    }

    if (e.type == DioExceptionType.connectionError) {
      return NetworkError(
        message: 'Network connection error',
        userMessage:
            'Unable to connect to the server. Please check your internet connection.',
        originalError: e,
      );
    }

    return NetworkError(
      message: e.message ?? 'Network error',
      originalError: e,
    );
  }
}
