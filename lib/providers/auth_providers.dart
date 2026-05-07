import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/entities/auth_result.dart';
import '../services/auth_manager.dart';
import '../services/passkey_auth_service.dart';
import '../services/provider_auth_service.dart';
import '../services/push_messaging_service.dart';
import '../services/socket_service.dart';
import '../constants/urls.dart';
import '../utils/jwt_utils.dart';
import '../utils/app_errors.dart';
import 'use_case_providers.dart';

final tokenProvider = StateProvider<String?>((ref) => null);
final sessionVersionProvider = StateProvider<int>((ref) => 0);

/// Path used by PersistCookieJar to store cookies on disk.
///
/// Overridden in `main.dart` after we resolve the application support directory,
/// to ensure the CookieManager is attached before the first network request.
final cookieStoragePathProvider = Provider<String?>((ref) => null);

// Initialize token from secure storage on app startup
final tokenInitializerProvider = FutureProvider<void>((ref) async {
  final storage = ref.read(secureStorageProvider);
  final token = await storage.read(key: 'auth_token');
  if (token != null && token.isNotEmpty) {
    ref.read(tokenProvider.notifier).state = token;
  }
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final providerAuthServiceProvider = Provider<ProviderAuthService>((ref) {
  return ProviderAuthService();
});

final passkeyAuthServiceProvider = Provider<PasskeyAuthService>((ref) {
  return PasskeyAuthService();
});

final pushMessagingServiceProvider = Provider<PushMessagingService>((ref) {
  return PushMessagingService();
});

// Auth manager provider
final authManagerProvider = Provider<AuthManager>((ref) {
  return AuthManager(ref);
});

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: ApiUrls.baseUrl,
    responseType: ResponseType.json,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  // Add logging interceptor (only in debug mode, sanitized)
  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      requestHeader: false, // Don't log headers (may contain tokens)
      responseHeader: false,
      error: true,
      logPrint: (object) {
        // Sanitize sensitive data in logs
        var sanitized = object.toString();
        // Remove token previews
        sanitized = sanitized.replaceAll(
          RegExp(r'Token preview: [^\s]+'),
          'Token preview: [REDACTED]',
        );
        sanitized = sanitized.replaceAllMapped(
          RegExp(
            r'"(idToken|identityToken|authorizationCode|rawNonce|challenge|token)"\s*:\s*"[^"]+"',
          ),
          (match) => '"${match.group(1)}": "[REDACTED]"',
        );
        print('API: $sanitized');
      },
    ));
  }

  // Initialize cookie manager eagerly (non-blocking)
  final authManager = ref.read(authManagerProvider);
  authManager.ensureCookieManagerInitialized(dio);

  // Add auth interceptor to inject Authorization header when token exists
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final authManager = ref.read(authManagerProvider);

      // Ensure cookie manager is initialized before making requests
      await authManager.ensureCookieManagerInitialized(dio);

      // Skip proactive refresh for refresh endpoint itself
      final reqExtra = options.extra;
      if (reqExtra['refresh'] == true) {
        handler.next(options);
        return;
      }

      final token = ref.read(tokenProvider);
      if (token != null && token.isNotEmpty) {
        // Proactive token refresh: check if token is expired or expiring soon
        if (JwtUtils.isTokenExpiredOrExpiringSoon(token, bufferMinutes: 5)) {
          // Token is expired or will expire soon, refresh it proactively
          if (!authManager.isLoggingOut) {
            try {
              final newToken = await authManager.refreshToken(dio);
              if (newToken != null && newToken.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $newToken';
              } else {
                // Refresh failed, use existing token and let error handler deal with it
                options.headers['Authorization'] = 'Bearer $token';
              }
            } catch (e) {
              // If refresh fails, use existing token and let error handler deal with it
              options.headers['Authorization'] = 'Bearer $token';
            }
          } else {
            options.headers['Authorization'] = 'Bearer $token';
          }
        } else {
          // Token is still valid, use it
          options.headers['Authorization'] = 'Bearer $token';
        }
      }
      handler.next(options);
    },
    onError: (error, handler) async {
      if (error.response?.statusCode == 401) {
        final authManager = ref.read(authManagerProvider);

        // Don't attempt refresh if we're already logging out
        if (authManager.isLoggingOut) {
          return handler.next(error);
        }

        // Skip refresh logic for refresh and logout calls
        final reqExtra = error.requestOptions.extra;
        if (reqExtra['refresh'] == true || reqExtra['logout'] == true) {
          // Refresh/logout failed - don't trigger another logout
          return handler.next(error);
        }

        // Check if token exists - if not, just return error (already logged out)
        final currentToken = ref.read(tokenProvider);
        if (currentToken == null || currentToken.isEmpty) {
          // No token - already logged out, don't call logout again
          return handler.next(error);
        }

        // Prevent infinite loop by checking a custom flag
        final requestOptions = error.requestOptions;
        final alreadyRetried = requestOptions.extra['retried'] == true;

        if (alreadyRetried) {
          // Already retried once, logout and don't retry again
          await authManager.logout();
          return handler.next(error);
        }

        // Attempt token refresh
        final token = await authManager.refreshToken(dio);
        if (token != null && !alreadyRetried) {
          // Retry original request once with new token
          final newOptions = Options(
            method: requestOptions.method,
            headers: Map<String, dynamic>.from(requestOptions.headers)
              ..['Authorization'] = 'Bearer $token',
            responseType: requestOptions.responseType,
            contentType: requestOptions.contentType,
            followRedirects: requestOptions.followRedirects,
            validateStatus: requestOptions.validateStatus,
            sendTimeout: requestOptions.sendTimeout,
            receiveTimeout: requestOptions.receiveTimeout,
            extra: {'retried': true},
          );
          try {
            final response = await dio.request(
              requestOptions.path,
              data: requestOptions.data,
              queryParameters: requestOptions.queryParameters,
              options: newOptions,
              cancelToken: requestOptions.cancelToken,
              onReceiveProgress: requestOptions.onReceiveProgress,
              onSendProgress: requestOptions.onSendProgress,
            );
            return handler.resolve(response);
          } catch (e) {
            // If retry also fails, logout and don't retry again
            await authManager.logout();
            return handler.next(error);
          }
        } else {
          // Refresh failed or already retried, logout
          await authManager.logout();
          return handler.next(error);
        }
      }
      return handler.next(error);
    },
  ));

  return dio;
});

// Current user info derived from JWT (no network call)
final currentUserProvider = Provider<Map<String, dynamic>?>((ref) {
  final token = ref.watch(tokenProvider);
  if (token == null || token.isEmpty) return null;

  final decoded = JwtUtils.decodeToken(token);
  if (decoded == null) return null;

  // Expect payload to include userId.
  final userId = decoded['userId'] ?? decoded['sub'];

  if (userId == null) return null;

  return {
    'id': userId.toString(),
  };
});

final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();

  // When the socket experiences an authentication error, refresh the token
  // and let SocketService reconnect/retry joins with the new token.
  service.refreshToken = () async {
    final authManager = ref.read(authManagerProvider);
    if (authManager.isLoggingOut) {
      return null;
    }

    try {
      final dio = ref.read(dioProvider);
      final newToken = await authManager.refreshToken(dio);

      if (newToken != null && newToken.isNotEmpty) {
        // AuthManager already persists + updates tokenProvider; return it for socket reconnect.
        return newToken;
      }
    } catch (_) {
      // Fall through to logout on any failure
    }

    await authManager.logout();
    return null;
  };

  // Keep socket's token in sync; SocketService maintains a single socket instance.
  ref.listen(tokenProvider, (previous, next) {
    if (next != null && next.isNotEmpty) {
      service.setToken(next);
    } else {
      service.setToken(null);
    }
  });

  // Initial token sync if token exists
  final token = ref.read(tokenProvider);
  if (token != null && token.isNotEmpty) {
    service.setToken(token);
  }

  // Cleanup on dispose
  ref.onDispose(() {
    service.disconnect();
  });

  return service;
});

final appleSignInAvailableProvider = FutureProvider<bool>((ref) async {
  final providerAuth = ref.read(providerAuthServiceProvider);
  return providerAuth.isAppleSignInAvailable();
});

final passkeySignInAvailableProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  final passkeyService = ref.read(passkeyAuthServiceProvider);
  final platformSupports = await passkeyService.isAvailable();
  if (!platformSupports) {
    return false;
  }

  final storage = ref.read(secureStorageProvider);
  final value = await storage.read(key: 'has_registered_passkey');
  return value == 'true';
});

final authSecurityStatusProvider =
    FutureProvider<AuthSecurityStatus>((ref) async {
  final token = ref.watch(tokenProvider);
  if (token == null || token.isEmpty) {
    return const AuthSecurityStatus(
      hasPasskey: false,
    );
  }

  final getSecurityStatus = ref.read(getAuthSecurityStatusUseCaseProvider);
  return getSecurityStatus();
});

// Logout provider to allow logout from UI
final logoutProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final authManager = ref.read(authManagerProvider);
    await authManager.logout();
  };
});

// Bootstrap provider to check authentication status on app startup
final bootstrapProvider = FutureProvider<bool>((ref) async {
  final authManager = ref.read(authManagerProvider);

  // Don't attempt refresh if we're in the middle of logging out
  if (authManager.isLoggingOut) {
    return false;
  }
  final storage = ref.read(secureStorageProvider);
  final existingToken = await storage.read(key: 'auth_token');

  if (existingToken != null && existingToken.isNotEmpty) {
    ref.read(tokenProvider.notifier).state = existingToken;
    try {
      final getProfileUseCase = ref.read(getProfileUseCaseProvider);
      // Validate the token by making a test API call.
      // The Dio interceptor will handle refresh and logout on 401/expired token.
      await getProfileUseCase();
      return true;
    } catch (e) {
      // Only logout on explicit 401s; otherwise keep token and let app show offline/retry
      final isUnauthorized = e is UnauthorizedError;
      if (isUnauthorized) {
        await authManager.logout();
        return false;
      }
      // Non-401 (e.g., 5xx/network): keep token; treat as not fully validated yet
      return true;
    }
  }

  // No token exists - don't attempt refresh, just return false
  return false;
});
