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
import '../constants/urls.dart';
import '../utils/navigation.dart';

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

  // Cookie manager with persistent cookie jar (for httpOnly refresh token)
  // Set up lazily because path_provider is async
  () async {
    final dir = await getApplicationSupportDirectory();
    final cookieJar =
        PersistCookieJar(storage: FileStorage('${dir.path}/cookies'));
    dio.interceptors.add(CookieManager(cookieJar));
  }();

  // Add auth interceptor to inject Authorization header when token exists
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      final token = ref.read(tokenProvider);
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (error, handler) async {
      if (error.response?.statusCode == 401) {
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
          _refreshingFuture = _refreshingCompleter!.future;
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
          refreshing =
              _refreshingFuture ?? Future.value(ref.read(tokenProvider));
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

// Helper function to logout user and navigate to auth screen
Future<void> _logoutUser(Ref ref) async {
  try {
    // Clear token
    ref.read(tokenProvider.notifier).state = null;

    // Clear secure storage
    final storage = ref.read(secureStorageProvider);
    await storage.delete(key: 'auth_token');

    // Disconnect socket
    final socketService = ref.read(socketServiceProvider);
    socketService.disconnect();

    // Navigate to authorization screen
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
  } catch (e) {
    print('Error during logout: $e');
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  final dio = ref.watch(dioProvider);
  final storage = ref.watch(secureStorageProvider);
  return AuthService(dio, storage);
});

final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();

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

// Bootstrap provider to check authentication status on app startup
final bootstrapProvider = FutureProvider<bool>((ref) async {
  final storage = ref.read(secureStorageProvider);
  final existingToken = await storage.read(key: 'auth_token');

  if (existingToken != null && existingToken.isNotEmpty) {
    ref.read(tokenProvider.notifier).state = existingToken;
    return true;
  }

  // Attempt silent refresh using httpOnly cookie
  try {
    final authService = ref.read(authServiceProvider);
    final newToken = await authService.refresh();
    ref.read(tokenProvider.notifier).state = newToken;
    return true;
  } catch (_) {
    return false;
  }
});
