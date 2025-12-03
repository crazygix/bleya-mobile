import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';
import '../services/user_service.dart';
import '../constants/urls.dart';
import '../utils/navigation.dart';
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

// Cookie jar singleton to ensure it's initialized before use
PersistCookieJar? _cookieJar;
CookieManager? _cookieManager;
Completer<void>? _cookieManagerInitCompleter;

Future<void> _ensureCookieManagerInitialized(Dio dio) async {
  if (_cookieManager != null) return;

  if (_cookieManagerInitCompleter != null) {
    return _cookieManagerInitCompleter!.future;
  }

  _cookieManagerInitCompleter = Completer<void>();
  try {
    final dir = await getApplicationSupportDirectory();
    _cookieJar = PersistCookieJar(storage: FileStorage('${dir.path}/cookies'));
    _cookieManager = CookieManager(_cookieJar!);
    dio.interceptors.add(_cookieManager!);
    _cookieManagerInitCompleter!.complete();
  } catch (e) {
    _cookieManagerInitCompleter!.completeError(e);
    _cookieManagerInitCompleter = null;
    rethrow;
  }
}

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
  _ensureCookieManagerInitialized(dio);

  // Add auth interceptor to inject Authorization header when token exists
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      // Ensure cookie manager is initialized before making requests
      await _ensureCookieManagerInitialized(dio);

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
          if (!_isLoggingOut) {
            try {
              // Single-flight refresh guard
              Future<String?>? refreshing = _refreshingFuture;
              if (refreshing == null) {
                _refreshingCompleter = Completer<String?>();
                refreshing = _refreshingCompleter!.future;
                _refreshingFuture = refreshing;
                try {
                  final refreshResponse = await dio.post(
                    '/auth/refresh',
                    options: Options(
                      extra: {'refresh': true},
                    ),
                  );
                  final String newToken = refreshResponse.data['token'];
                  final storage = ref.read(secureStorageProvider);
                  await storage.write(key: 'auth_token', value: newToken);
                  ref.read(tokenProvider.notifier).state = newToken;
                  _refreshingCompleter?.complete(newToken);
                } catch (e) {
                  print('Proactive token refresh failed: $e');
                  _refreshingCompleter?.complete(null);
                } finally {
                  _refreshingCompleter = null;
                  _refreshingFuture = null;
                }
              }

              final newToken = await refreshing;
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
        // Don't attempt refresh if we're already logging out
        if (_isLoggingOut) {
          return handler.next(error);
        }

        // Skip refresh logic for refresh calls themselves
        final reqExtra = error.requestOptions.extra;
        if (reqExtra['refresh'] == true) {
          // Refresh failed - logout user and navigate to auth screen
          await _logoutUser(ref);
          return handler.next(error);
        }

        // Check if token exists - if not, logout immediately
        final currentToken = ref.read(tokenProvider);
        if (currentToken == null || currentToken.isEmpty) {
          // No token at all - logout immediately
          await _logoutUser(ref);
          return handler.next(error);
        }

        // Prevent infinite loop by checking a custom flag
        final requestOptions = error.requestOptions;
        final alreadyRetried = requestOptions.extra['retried'] == true;

        if (alreadyRetried) {
          // Already retried once, logout and don't retry again
          await _logoutUser(ref);
          return handler.next(error);
        }

        // Single-flight refresh guard
        Future<String?>? refreshing = _refreshingFuture;
        if (refreshing == null) {
          _refreshingCompleter = Completer<String?>();
          refreshing = _refreshingCompleter!.future;
          _refreshingFuture = refreshing;
          try {
            // Perform refresh directly using the same Dio instance.
            // Cookies (httpOnly refresh token) are attached by CookieManager.
            final refreshResponse = await dio.post(
              '/auth/refresh',
              options: Options(
                // Mark as refresh to avoid recursive handling
                extra: {'refresh': true},
              ),
            );
            final String newToken = refreshResponse.data['token'];
            // Persist token securely
            final storage = ref.read(secureStorageProvider);
            await storage.write(key: 'auth_token', value: newToken);
            ref.read(tokenProvider.notifier).state = newToken;
            _refreshingCompleter?.complete(newToken);
          } catch (e) {
            print('Token refresh failed: $e');
            // Refresh failed - logout user
            await _logoutUser(ref);
            _refreshingCompleter?.complete(null);
          } finally {
            _refreshingCompleter = null;
            _refreshingFuture = null;
          }
        }

        final token = await refreshing;
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
            print('Retry after refresh also failed: $e');
            await _logoutUser(ref);
            return handler.next(error);
          }
        } else {
          // Refresh failed or already retried, logout
          await _logoutUser(ref);
          return handler.next(error);
        }
      }
      return handler.next(error);
    },
  ));

  return dio;
});

// Single-flight refresh synchronization
Completer<String?>? _refreshingCompleter;
Future<String?>? _refreshingFuture;

// Flag to prevent bootstrap refresh loop
bool _isLoggingOut = false;

// Helper function to logout user and navigate to auth screen
Future<void> _logoutUser(Ref ref) async {
  // Prevent multiple simultaneous logout calls
  if (_isLoggingOut) return;
  _isLoggingOut = true;

  try {
    // Clear token
    ref.read(tokenProvider.notifier).state = null;

    // Clear secure storage
    final storage = ref.read(secureStorageProvider);
    await storage.delete(key: 'auth_token');

    // Clear cookies by calling logout endpoint
    try {
      final authService = ref.read(authServiceProvider);
      await authService.logout();
    } catch (e) {
      // If logout endpoint fails, still continue with local cleanup
      print('Logout endpoint call failed: $e');
    }

    // Clear cookie jar to ensure cookies are removed
    if (_cookieJar != null) {
      try {
        await _cookieJar!.deleteAll();
      } catch (e) {
        print('Error clearing cookie jar: $e');
      }
    }

    // Disconnect socket
    final socketService = ref.read(socketServiceProvider);
    socketService.disconnect();

    // Navigate to authorization screen (InitialPage will show AuthorisationPage when not authenticated)
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);

    // Don't invalidate bootstrapProvider here - it causes a loop
    // The bootstrap will naturally re-check when the app restarts or navigates
  } catch (e) {
    print('Error during logout: $e');
  } finally {
    _isLoggingOut = false;
  }
}

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
    await _logoutUser(ref);
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
    await _logoutUser(ref);
  };
});

// Bootstrap provider to check authentication status on app startup
final bootstrapProvider = FutureProvider<bool>((ref) async {
  // Don't attempt refresh if we're in the middle of logging out
  if (_isLoggingOut) {
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
      await _logoutUser(ref);
      return false;
    }
  }

  // No token exists - don't attempt refresh, just return false
  return false;
});
