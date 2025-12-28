import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
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
      final storagePath = _ref.read(cookieStoragePathProvider);
      // Fallback for safety (should be overridden in main.dart)
      final basePath = (storagePath != null && storagePath.isNotEmpty)
          ? storagePath
          : '${Directory.systemTemp.path}/bleya';

      _cookieJar = PersistCookieJar(
        storage: FileStorage('$basePath/cookies'),
      );
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
      // Disconnect socket first (before token clear to prevent reconnect attempts)
      final socketService = _ref.read(socketServiceProvider);
      socketService.disconnect();

      // Clear token and storage FIRST (before any navigation)
      _ref.read(tokenProvider.notifier).state = null;
      final storage = _ref.read(secureStorageProvider);
      await storage.delete(key: 'auth_token');

      // Invalidate bootstrapProvider to prevent it from using cached authenticated state
      _ref.invalidate(bootstrapProvider);

      // Call logout endpoint to clear server-side refresh token
      try {
        final authService = _ref.read(authServiceProvider);
        await authService.logout();
      } catch (e) {
        // If logout endpoint fails, still continue with local cleanup
      }

      // Clear cookie jar
      if (_cookieJar != null) {
        try {
          await _cookieJar!.deleteAll();
        } catch (e) {
          // Error clearing cookie jar - non-critical
        }
      }

      // Navigate to authorization screen LAST (after all cleanup)
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
    } finally {
      _isLoggingOut = false;
    }
  }
}
