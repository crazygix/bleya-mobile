// Custom error classes for the application
// These provide structured error handling with user-friendly messages

enum AppErrorCode {
  // Network errors
  networkError,
  connectionTimeout,
  receiveTimeout,

  // Client errors (4xx)
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  tooManyRequests,

  // Server errors (5xx)
  serverError,
  serviceUnavailable,

  // Unknown errors
  unknown,
}

class AppError implements Exception {
  final AppErrorCode code;
  final String message;
  final String? userMessage;
  final dynamic originalError;
  final Map<String, dynamic>? details;

  AppError({
    required this.code,
    required this.message,
    this.userMessage,
    this.originalError,
    this.details,
  });

  /// Get user-friendly error message
  String getUserMessage() {
    return userMessage ?? _getDefaultUserMessage();
  }

  String _getDefaultUserMessage() {
    switch (code) {
      case AppErrorCode.networkError:
      case AppErrorCode.connectionTimeout:
      case AppErrorCode.receiveTimeout:
        return 'Network connection failed. Please check your internet connection and try again.';

      case AppErrorCode.badRequest:
        return 'Invalid request. Please check your input and try again.';

      case AppErrorCode.unauthorized:
        return 'Your session has expired. Please log in again.';

      case AppErrorCode.forbidden:
        return 'You don\'t have permission to perform this action.';

      case AppErrorCode.notFound:
        return 'The requested resource was not found.';

      case AppErrorCode.conflict:
        return 'This action conflicts with existing data.';

      case AppErrorCode.tooManyRequests:
        return 'Too many attempts. Please try again later.';

      case AppErrorCode.serverError:
        return 'Server error occurred. Please try again later.';

      case AppErrorCode.serviceUnavailable:
        return 'Service is temporarily unavailable. Please try again later.';

      case AppErrorCode.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  @override
  String toString() => message;
}

/// Network-related errors
class NetworkError extends AppError {
  NetworkError({
    String? message,
    super.userMessage,
    super.originalError,
  }) : super(
          code: AppErrorCode.networkError,
          message: message ?? 'Network error occurred',
        );
}

/// Validation/Bad Request errors
class BadRequestError extends AppError {
  BadRequestError({
    String? message,
    String? userMessage,
    super.details,
    super.originalError,
  }) : super(
          code: AppErrorCode.badRequest,
          message: message ?? 'Bad request',
          userMessage:
              userMessage ?? 'Invalid request. Please check your input.',
        );
}

/// Unauthorized errors
class UnauthorizedError extends AppError {
  UnauthorizedError({
    String? message,
    String? userMessage,
    super.originalError,
  }) : super(
          code: AppErrorCode.unauthorized,
          message: message ?? 'Unauthorized',
          userMessage:
              userMessage ?? 'Your session has expired. Please log in again.',
        );
}

/// Not Found errors
class NotFoundError extends AppError {
  NotFoundError({
    String? message,
    String? userMessage,
    super.originalError,
  }) : super(
          code: AppErrorCode.notFound,
          message: message ?? 'Resource not found',
          userMessage: userMessage ?? 'The requested resource was not found.',
        );
}

/// Server errors
class ServerError extends AppError {
  ServerError({
    String? message,
    String? userMessage,
    super.originalError,
  }) : super(
          code: AppErrorCode.serverError,
          message: message ?? 'Server error',
          userMessage:
              userMessage ?? 'Server error occurred. Please try again later.',
        );
}

/// Too Many Requests error
class TooManyRequestsError extends AppError {
  TooManyRequestsError({
    String? message,
    String? userMessage,
    super.originalError,
  }) : super(
          code: AppErrorCode.tooManyRequests,
          message: message ?? 'Too many requests',
          userMessage:
              userMessage ?? 'Too many attempts. Please try again later.',
        );
}

/// Forbidden errors
class ForbiddenError extends AppError {
  ForbiddenError({
    String? message,
    String? userMessage,
    super.originalError,
  }) : super(
          code: AppErrorCode.forbidden,
          message: message ?? 'Forbidden',
          userMessage: userMessage ??
              'You don\'t have permission to perform this action.',
        );
}

/// Conflict errors
class ConflictError extends AppError {
  ConflictError({
    String? message,
    String? userMessage,
    super.details,
    super.originalError,
  }) : super(
          code: AppErrorCode.conflict,
          message: message ?? 'Conflict',
          userMessage:
              userMessage ?? 'This action conflicts with existing data.',
        );
}

/// Service Unavailable errors
class ServiceUnavailableError extends AppError {
  ServiceUnavailableError({
    String? message,
    String? userMessage,
    super.originalError,
  }) : super(
          code: AppErrorCode.serviceUnavailable,
          message: message ?? 'Service unavailable',
          userMessage: userMessage ??
              'Service is temporarily unavailable. Please try again later.',
        );
}
