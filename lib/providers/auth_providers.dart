import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';
import '../constants/urls.dart';

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
          return handler.next(error);
        }
        // Prevent infinite loop by checking a custom flag
        final requestOptions = error.requestOptions;
        final alreadyRetried = requestOptions.extra['retried'] == true;

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
          );
          requestOptions.extra['retried'] = true;
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
            // fall through to original error handler
          }
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

final authServiceProvider = Provider<AuthService>((ref) {
  final dio = ref.watch(dioProvider);
  final storage = ref.watch(secureStorageProvider);
  return AuthService(dio, storage);
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
