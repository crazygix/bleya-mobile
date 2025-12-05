import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';
import '../services/auth_manager.dart';
import '../services/socket_service.dart';
import '../services/user_service.dart';
import '../constants/urls.dart';
import '../utils/jwt_utils.dart';

final tokenProvider = StateProvider<String?>((ref) => null);

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

  // Add logging interceptor
  dio.interceptors.add(LogInterceptor(
    requestBody: true,
    responseBody: true,
    requestHeader: true,
    responseHeader: false,
    error: true,
    logPrint: (object) {
      if (kDebugMode) {
        print('🌐 API: $object');
      }
    },
  ));

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

        // Skip refresh logic for refresh calls themselves
        final reqExtra = error.requestOptions.extra;
        if (reqExtra['refresh'] == true) {
          // Refresh failed - logout user and navigate to auth screen
          await authManager.logout();
          return handler.next(error);
        }

        // Check if token exists - if not, logout immediately
        final currentToken = ref.read(tokenProvider);
        if (currentToken == null || currentToken.isEmpty) {
          // No token at all - logout immediately
          await authManager.logout();
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

final authServiceProvider = Provider<AuthService>((ref) {
  final dio = ref.watch(dioProvider);
  final storage = ref.watch(secureStorageProvider);
  return AuthService(dio, storage);
});

final userServiceProvider = Provider<UserService>((ref) {
  final dio = ref.watch(dioProvider);
  return UserService(dio);
});

// Current user profile provider
final currentUserProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  try {
    final userService = ref.read(userServiceProvider);
    return await userService.getProfile();
  } catch (e) {
    return null;
  }
});

final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();

  // When the socket experiences an authentication error, route it through
  // the same logout flow used for HTTP authentication failures.
  service.onAuthError = () async {
    final authManager = ref.read(authManagerProvider);
    await authManager.logout();
  };

  // Connect socket when token is available
  ref.listen(tokenProvider, (previous, next) {
    if (next != null && next.isNotEmpty) {
      service.connect(next);
    } else {
      service.disconnect();
    }
  });

  // Initial connection if token exists
  final token = ref.read(tokenProvider);
  if (token != null && token.isNotEmpty) {
    service.connect(token);
  }

  // Cleanup on dispose
  ref.onDispose(() {
    service.disconnect();
  });

  return service;
});

// Logout provider to allow logout from UI
final logoutProvider = Provider<void Function()>((ref) {
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
      final userService = ref.read(userServiceProvider);
      // Validate the token by making a test API call.
      // The Dio interceptor will handle refresh and logout on 401/expired token.
      await userService.getProfile();
      return true;
    } catch (e) {
      // If validation fails (including after any interceptor refresh attempts),
      // ensure the user is logged out and treated as unauthenticated.
      await authManager.logout();
      return false;
    }
  }

  // No token exists - don't attempt refresh, just return false
  return false;
});
