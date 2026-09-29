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
        var authToken = token;
        // Proactive token refresh: check if token is expired or expiring soon
        if (JwtUtils.isTokenExpiredOrExpiringSoon(token, bufferMinutes: 5) &&
            !authManager.isLoggingOut) {
          final result = await authManager.refreshSession(dio);
          switch (result) {
            case TokenRefreshed(token: final newToken):
              authToken = newToken;
            case SessionEnded(:final message, :final error):
              // The refresh already cleared the cookie, so handle it here:
              // a later 401 could no longer tell a ban from an expired session.
              await authManager.endSession(message: message);
              return handler.reject(
                error?.copyWith(requestOptions: options) ??
                    DioException(
                      requestOptions: options,
                      message: 'Session ended',
                    ),
              );
            case RefreshUnavailable():
              // Keep the current token. If it has already expired, the
              // request gets a 401 and the error path below decides.
              break;
          }
        }
        options.headers['Authorization'] = 'Bearer $authToken';
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

        final requestOptions = error.requestOptions;
        if (requestOptions.extra['retried'] == true) {
          // Rejected again right after a successful refresh: the session is
          // no longer valid.
          await authManager.endSession();
          return handler.next(error);
        }

        final result = await authManager.refreshSession(dio);
        switch (result) {
          case TokenRefreshed(:final token):
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
              extra: {...requestOptions.extra, 'retried': true},
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
            } on DioException catch (retryError) {
              // A 401 on the retry has already ended the session (above);
              // anything else (offline, 5xx) is just this request failing.
              return handler.next(retryError);
            } catch (_) {
              return handler.next(error);
            }
          case SessionEnded(:final message):
            await authManager.endSession(message: message);
            return handler.next(error);
          case RefreshUnavailable(error: final refreshError):
            // Keep the session. Fail with the temporary cause (offline, rate
            // limit, server error) instead of the 401, so callers don't treat
            // this as signed out.
            return handler.next(
              refreshError?.copyWith(requestOptions: requestOptions) ??
                  DioException(
                    requestOptions: requestOptions,
                    type: DioExceptionType.connectionError,
                    message: 'Session refresh unavailable',
                  ),
            );
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

/// Holds a fatal account message (e.g. a ban reason) to surface after a forced
/// logout triggered by a socket ban rejection.
final fatalAuthMessageProvider = StateProvider<String?>((ref) => null);

final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();

  // When the socket experiences an authentication error, refresh the token
  // and let SocketService reconnect/retry joins with the new token. Returns
  // null when there is no new token: after a logout if the session ended, or
  // with the session kept if the refresh was only temporarily unavailable.
  service.refreshToken = () async {
    final authManager = ref.read(authManagerProvider);
    if (authManager.isLoggingOut) {
      return null;
    }

    final result = await authManager.refreshSession(ref.read(dioProvider));
    switch (result) {
      case TokenRefreshed(:final token):
        // AuthManager already persists + updates tokenProvider; return it for socket reconnect.
        return token;
      case SessionEnded(:final message):
        await authManager.endSession(message: message);
        return null;
      case RefreshUnavailable():
        return null;
    }
  };

  // Non-auth socket rejection (ban/suspend): surface the reason and log out so
  // the client stops trying to reconnect into the same rejection.
  service.onFatalError = (message) async {
    await ref.read(authManagerProvider).endSession(message: message);
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

/// Passkeys registered to the signed-in account (Settings → Passkeys).
final passkeysProvider =
    FutureProvider.autoDispose<List<PasskeySummary>>((ref) async {
  ref.watch(sessionVersionProvider);
  final token = ref.read(tokenProvider);
  if (token == null || token.isEmpty) {
    return const [];
  }
  return ref.read(listPasskeysUseCaseProvider)();
});

/// Whether this device can create passkeys at all.
final passkeyPlatformSupportedProvider =
    FutureProvider.autoDispose<bool>((ref) {
  return ref.read(passkeyAuthServiceProvider).isAvailable();
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
