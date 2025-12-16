import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../utils/navigation.dart';

/// Manages authentication state, token refresh, and logout flow
class AuthManager {
  final Ref _ref;

  // Single-flight refresh synchronization
  Completer<String?>? _refreshingCompleter;
  Future<String?>? _refreshingFuture;

  // Flag to prevent bootstrap refresh loop
  bool _isLoggingOut = false;

  // Cookie jar singleton
  PersistCookieJar? _cookieJar;
  CookieManager? _cookieManager;
  Completer<void>? _cookieManagerInitCompleter;

  AuthManager(this._ref);

  /// Initialize cookie manager for Dio
  Future<void> ensureCookieManagerInitialized(Dio dio) async {
    if (_cookieManager != null) return;

    if (_cookieManagerInitCompleter != null) {
      return _cookieManagerInitCompleter!.future;
    }

    _cookieManagerInitCompleter = Completer<void>();
    try {
      final dir = await getApplicationSupportDirectory();
      _cookieJar =
          PersistCookieJar(storage: FileStorage('${dir.path}/cookies'));
      _cookieManager = CookieManager(_cookieJar!);
      dio.interceptors.add(_cookieManager!);
      _cookieManagerInitCompleter!.complete();
    } catch (e) {
      _cookieManagerInitCompleter!.completeError(e);
      _cookieManagerInitCompleter = null;
      rethrow;
    }
  }

  /// Check if currently logging out
  bool get isLoggingOut => _isLoggingOut;

  /// Refresh access token using refresh token cookie
  /// Returns new token or null if refresh failed
  Future<String?> refreshToken(Dio dio) async {
    // Single-flight refresh guard
    Future<String?>? refreshing = _refreshingFuture;
    if (refreshing == null) {
      _refreshingCompleter = Completer<String?>();
      refreshing = _refreshingCompleter!.future;
      _refreshingFuture = refreshing;

      try {
        // Ensure cookies are attached before calling refresh
        await ensureCookieManagerInitialized(dio);

        final refreshResponse = await dio.post(
          '/auth/refresh',
          options: Options(
            extra: {'refresh': true},
          ),
        );
        final String newToken = refreshResponse.data['token'];

        // Persist token securely
        final storage = _ref.read(secureStorageProvider);
        await storage.write(key: 'auth_token', value: newToken);
        _ref.read(tokenProvider.notifier).state = newToken;

        _refreshingCompleter?.complete(newToken);
      } catch (e) {
        _refreshingCompleter?.complete(null);
      } finally {
        _refreshingCompleter = null;
        _refreshingFuture = null;
      }
    }

    return await refreshing;
  }

  /// Logout user and navigate to auth screen
  /// Clears token, cookies, disconnects socket, and navigates
  Future<void> logout() async {
    // Prevent multiple simultaneous logout calls
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    try {
      // Clear token
      _ref.read(tokenProvider.notifier).state = null;

      // Clear secure storage
      final storage = _ref.read(secureStorageProvider);
      await storage.delete(key: 'auth_token');

      // Clear cookies by calling logout endpoint
      try {
        final authService = _ref.read(authServiceProvider);
        await authService.logout();
      } catch (e) {
        // If logout endpoint fails, still continue with local cleanup
        // Error is logged but doesn't block logout
      }

      // Clear cookie jar to ensure cookies are removed
      if (_cookieJar != null) {
        try {
          await _cookieJar!.deleteAll();
        } catch (e) {
          // Error clearing cookie jar - non-critical
        }
      }

      // Disconnect socket
      final socketService = _ref.read(socketServiceProvider);
      socketService.disconnect();

      // Navigate to authorization screen
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
    } finally {
      _isLoggingOut = false;
    }
  }
}
