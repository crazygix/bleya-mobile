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
        return "Connection issue. Check your internet and try again?";

      case AppErrorCode.badRequest:
        return "Something's not quite right. Check your input and try again?";

      case AppErrorCode.unauthorized:
        return "Your session expired. Sign in again?";

      case AppErrorCode.forbidden:
        return "You don't have permission to do that.";

      case AppErrorCode.notFound:
        return "Couldn't find that. Try again?";

      case AppErrorCode.conflict:
        return "That conflicts with something else. Try again?";

      case AppErrorCode.tooManyRequests:
        return "Too many tries. Give it a moment and try again?";

      case AppErrorCode.serverError:
        return "Something went wrong on our end. Try again in a bit?";

      case AppErrorCode.serviceUnavailable:
        return "We're temporarily unavailable. Try again soon?";

      case AppErrorCode.unknown:
        return "Something unexpected happened. Try again?";
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
              userMessage ?? "Something's not quite right. Check your input and try again?",
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
              userMessage ?? "Your session expired. Sign in again?",
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
          userMessage: userMessage ?? "Couldn't find that. Try again?",
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
              userMessage ?? "Something went wrong on our end. Try again in a bit?",
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
              userMessage ?? "Too many tries. Give it a moment and try again?",
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
              "You don't have permission to do that.",
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
              userMessage ?? "That conflicts with something else. Try again?",
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
              "We're temporarily unavailable. Try again soon?",
        );
}
