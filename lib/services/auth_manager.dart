import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../providers/repository_providers.dart';
import '../providers/use_case_providers.dart';
import '../utils/navigation.dart';
import 'secure_cookie_storage.dart';

/// Outcome of exchanging the refresh cookie for a new access token.
sealed class TokenRefreshResult {
  const TokenRefreshResult();
}

/// The server issued a new access token.
final class TokenRefreshed extends TokenRefreshResult {
  final String token;

  const TokenRefreshed(this.token);
}

/// The session is over: the refresh token was rejected (401), or the account
/// is banned or suspended (403). [message] is the server's reason for a 403.
final class SessionEnded extends TokenRefreshResult {
  final String? message;
  final DioException? error;

  const SessionEnded({this.message, this.error});
}

/// The refresh couldn't happen right now (offline, timeout, rate limit,
/// server error). The session itself is still valid.
final class RefreshUnavailable extends TokenRefreshResult {
  final DioException? error;

  const RefreshUnavailable([this.error]);
}

/// Manages authentication state, token refresh, and logout flow
class AuthManager {
  final Ref _ref;

  // Single-flight refresh synchronization
  Completer<TokenRefreshResult>? _refreshCompleter;

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

      // The refresh cookie lives in secure storage. Until the one-time move
      // out of the old plain files has succeeded, keep reading those files so
      // the user isn't signed out.
      final usesLegacyFiles =
          SessionStorageMigration.usesLegacyCookieFiles(basePath);
      final Storage storage = usesLegacyFiles
          ? FileStorage(SessionStorageMigration.legacyCookieFolder(basePath))
          : SecureCookieStorage(_ref.read(secureStorageProvider));

      _cookieJar = PersistCookieJar(storage: storage);
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

  /// Exchanges the refresh cookie for a new access token. Concurrent callers
  /// share one request. Never throws.
  Future<TokenRefreshResult> refreshSession(Dio dio) {
    final pending = _refreshCompleter;
    if (pending != null) return pending.future;

    final completer = Completer<TokenRefreshResult>();
    _refreshCompleter = completer;
    _performRefresh(dio).then((result) {
      _refreshCompleter = null;
      completer.complete(result);
    });
    return completer.future;
  }

  Future<TokenRefreshResult> _performRefresh(Dio dio) async {
    final sessionVersion = _ref.read(sessionVersionProvider);
    try {
      // Ensure cookies are attached before calling refresh
      await ensureCookieManagerInitialized(dio);

      final response = await dio.post(
        '/auth/refresh',
        options: Options(
          extra: {'refresh': true},
        ),
      );
      final data = response.data;
      final token = data is Map ? data['token'] : null;
      if (token is! String || token.isEmpty) {
        return const RefreshUnavailable();
      }
      if (_isLoggingOut ||
          _ref.read(sessionVersionProvider) != sessionVersion) {
        // Signed out while the refresh was in flight: don't bring the old
        // session back.
        return const RefreshUnavailable();
      }

      _ref.read(tokenProvider.notifier).state = token;
      try {
        final storage = _ref.read(secureStorageProvider);
        await storage.write(key: 'auth_token', value: token);
      } catch (_) {
        // The in-memory token still works for this run of the app.
      }
      return TokenRefreshed(token);
    } on DioException catch (e) {
      return classifyRefreshFailure(e);
    } catch (_) {
      return const RefreshUnavailable();
    }
  }

  /// Only a rejected session (401) or a banned/suspended account (403) ends
  /// the session; the server clears the refresh cookie for exactly those.
  /// Everything else (offline, timeout, 429, 5xx) is temporary.
  static TokenRefreshResult classifyRefreshFailure(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode == 401) {
      return SessionEnded(error: error);
    }
    if (statusCode == 403) {
      return SessionEnded(
        message: _serverMessage(error.response?.data),
        error: error,
      );
    }
    return RefreshUnavailable(error);
  }

  static String? _serverMessage(dynamic data) {
    if (data is! Map) return null;
    final errorData = data['error'];
    final message = errorData is Map ? errorData['message'] : null;
    if (message is! String || message.trim().isEmpty) return null;
    return message.trim();
  }

  /// Logs out because the server ended the session. A [message] (such as a
  /// ban reason) is shown on the sign-in screen. Never throws: it runs inside
  /// the HTTP and socket error paths, where an exception would leave the
  /// failed request unanswered.
  Future<void> endSession({String? message}) async {
    if (message != null && message.isNotEmpty) {
      _ref.read(fatalAuthMessageProvider.notifier).state = message;
    }
    if (_isLoggingOut) return;
    try {
      await logout();
    } catch (e) {
      if (kDebugMode) {
        print('Logout after the session ended failed: $e');
      }
    }
  }

  /// Logout user and navigate to auth screen
  /// Clears token, cookies, disconnects socket, and navigates
  Future<void> logout() async {
    // Prevent multiple simultaneous logout calls
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    try {
      final authToken = _ref.read(tokenProvider);
      if (authToken != null && authToken.isNotEmpty) {
        try {
          final pushToken = await _ref.read(pushMessagingServiceProvider).getToken();
          if (pushToken != null && pushToken.isNotEmpty) {
            await _ref.read(unregisterPushTokenUseCaseProvider).call(
                  token: pushToken,
                );
          }
        } catch (_) {
          // Best-effort cleanup only.
        }
      }

      // Disconnect socket first (before token clear to prevent reconnect attempts)
      final socketService = _ref.read(socketServiceProvider);
      socketService.disconnect();

      // Clear token and storage FIRST (before any navigation). Clearing the
      // token ends the session: sessionVersionProvider follows it, so
      // session-scoped providers drop the previous account's data.
      _ref.read(tokenProvider.notifier).state = null;
      final storage = _ref.read(secureStorageProvider);
      await storage.delete(key: 'auth_token');

      // Invalidate bootstrapProvider to prevent it from using cached authenticated state
      _ref.invalidate(bootstrapProvider);

      // Call logout endpoint to clear server-side refresh token
      try {
        final authRepository = _ref.read(authRepositoryProvider);
        await authRepository.logout();
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
