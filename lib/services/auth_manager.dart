import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/urls.dart';
import '../providers/auth_providers.dart';
import '../providers/repository_providers.dart';
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

/// The session's [CookieManager]. A response to a request that was
/// cancelled stores no cookies, and [whenSaved] waits for the saves already
/// under way, so a sign-out can clear the jar after them.
class _SessionCookieManager extends CookieManager {
  _SessionCookieManager(super.cookieJar);

  final Set<Future<void>> _saving = {};

  /// Completes once every cookie save under way has finished.
  Future<void> whenSaved() => Future.wait(List.of(_saving));

  @override
  Future<void> saveCookies(Response response) {
    if (response.requestOptions.cancelToken?.isCancelled ?? false) {
      return Future.value();
    }
    final save = super.saveCookies(response);
    final saved = save.then<void>((_) {}, onError: (Object _) {});
    _saving.add(saved);
    unawaited(saved.whenComplete(() => _saving.remove(saved)));
    return save;
  }
}

/// Manages authentication state, token refresh, and logout flow
class AuthManager {
  static const _refreshCookieName = 'refreshToken';

  // Signing out of Google is local, but it must not hold up the sign-out.
  static const _providerSignOutTimeout = Duration(seconds: 2);

  final Ref _ref;

  // Single-flight refresh synchronization
  Completer<TokenRefreshResult>? _refreshCompleter;

  // Cancels the refresh in flight when the user signs out.
  CancelToken? _refreshCancelToken;

  // Set while signing out, so nothing refreshes or restores the session
  // meanwhile (including the bootstrap of the intro it navigates to).
  bool _isLoggingOut = false;

  // The sign-out in progress, shared by calls made while it runs.
  Future<void>? _logout;

  // Cookie jar singleton
  PersistCookieJar? _cookieJar;
  _SessionCookieManager? _cookieManager;
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
      _cookieManager = _SessionCookieManager(_cookieJar!);
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
    // Signing out: nothing may bring the session back.
    if (_isLoggingOut) {
      return Future.value(const RefreshUnavailable());
    }
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
    final cancelToken = CancelToken();
    _refreshCancelToken = cancelToken;
    try {
      // Ensure cookies are attached before calling refresh
      await ensureCookieManagerInitialized(dio);

      final response = await dio.post(
        '/auth/refresh',
        options: Options(
          extra: {'refresh': true},
        ),
        cancelToken: cancelToken,
      );
      final data = response.data;
      final token = data is Map ? data['token'] : null;
      if (token is! String || token.isEmpty) {
        return const RefreshUnavailable();
      }
      if (_isLoggingOut ||
          cancelToken.isCancelled ||
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
      // A refresh cancelled by a sign-out ends up here too, as temporary.
      return classifyRefreshFailure(e);
    } catch (_) {
      return const RefreshUnavailable();
    } finally {
      if (identical(_refreshCancelToken, cancelToken)) {
        _refreshCancelToken = null;
      }
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

  /// Signs out. This device is cleared first, so the intro shows at once,
  /// even offline: the refresh in flight is cancelled, the socket is
  /// disconnected, and the token, the stored session and the cookies are
  /// deleted before navigating. Then the app-icon badge, the Google session
  /// and the data export go, and last, without waiting, the session is ended
  /// on the server and this device's push token is deleted.
  ///
  /// [accountDeleted] also forgets the passkey this device signs in with; a
  /// plain logout keeps it, so a returning user can still use it. Calls made
  /// while a sign-out runs share it.
  Future<void> logout({bool accountDeleted = false}) {
    final running = _logout;
    if (running != null) {
      return accountDeleted
          ? running.then((_) => _forgetRegisteredPasskey())
          : running;
    }
    _isLoggingOut = true;
    return _logout = _signOut(accountDeleted: accountDeleted);
  }

  Future<void> _signOut({required bool accountDeleted}) async {
    String? refreshCookie;
    try {
      // A refresh still running could store a new token or session cookie.
      await _step('stop the token refresh', _cancelRefresh);
      // Ends this session on the server below.
      refreshCookie = await _readRefreshCookie();

      await _step(
        'disconnect the socket',
        () => _ref.read(socketServiceProvider).disconnect(),
      );
      // Clearing the token ends the session: sessionVersionProvider follows
      // it, so session-scoped providers drop the previous account's data.
      _ref.read(tokenProvider.notifier).state = null;
      await _step(
        'delete the stored token',
        () => _ref.read(secureStorageProvider).delete(key: 'auth_token'),
      );
      await _step('delete the cookies', () => _cookieJar?.deleteAll());

      _ref.invalidate(bootstrapProvider);
      await _step('show the intro', () {
        unawaited(navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/', (route) => false));
      });

      // Signed out on this device. What follows doesn't hold up the intro.
      // The app-icon badge counted this account's unread chats.
      await _step(
        'clear the app badge',
        () => _ref.read(appBadgeServiceProvider).setBadgeCount(0),
      );
      await _step(
        'sign out of Google',
        () => _ref
            .read(providerAuthServiceProvider)
            .clearCachedProviderSession()
            .timeout(_providerSignOutTimeout),
      );
      await _step(
        'delete the data export',
        () => _ref.read(dataExportFileProvider).deleteAll(),
      );
      if (accountDeleted) {
        await _forgetRegisteredPasskey();
      }
    } finally {
      _isLoggingOut = false;
      _logout = null;
    }
    unawaited(_endRemoteSession(refreshCookie));
  }

  /// Cancels the refresh in flight and waits for it, including a cookie it
  /// was already saving, so nothing it brings back outlives the sign-out.
  Future<void> _cancelRefresh() async {
    final refresh = _refreshCompleter;
    if (refresh == null) return;
    _refreshCancelToken?.cancel('Signed out');
    await refresh.future;
    await _cookieManager?.whenSaved();
  }

  /// The refresh cookie of the session being signed out, or null without one.
  Future<String?> _readRefreshCookie() async {
    try {
      await ensureCookieManagerInitialized(_ref.read(dioProvider));
      final cookies =
          await _cookieJar!.loadForRequest(Uri.parse(ApiUrls.baseUrl));
      for (final cookie in cookies) {
        if (cookie.name == _refreshCookieName && cookie.value.isNotEmpty) {
          return cookie.value;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Sign-out: reading the session cookie failed: $e');
      }
    }
    return null;
  }

  /// Ends the signed-out session on the server and deletes this device's
  /// push token, so the account's pushes stop. It runs after the device is
  /// signed out and never touches the token, secure storage or the cookie
  /// jar, which may belong to the next session by then.
  Future<void> _endRemoteSession(String? refreshCookie) async {
    await Future.wait([
      if (refreshCookie != null)
        _step(
          'end the session on the server',
          () => _ref.read(sessionCleanupDioProvider).post(
                '/auth/logout',
                options: Options(headers: {
                  HttpHeaders.cookieHeader:
                      '$_refreshCookieName=$refreshCookie',
                }),
              ),
        ),
      _step(
        'delete the push token',
        () => _ref.read(pushMessagingServiceProvider).deleteTokenAfterSignOut(),
      ),
    ]);
  }

  Future<void> _forgetRegisteredPasskey() {
    return _step(
      'forget the passkey',
      () => _ref.read(authRepositoryProvider).forgetRegisteredPasskey(),
    );
  }

  /// Runs one sign-out step. A step that fails is skipped, so the rest of
  /// the sign-out still happens.
  static Future<void> _step(
    String name,
    FutureOr<void> Function() step,
  ) async {
    try {
      await step();
    } catch (e) {
      if (kDebugMode) {
        print("Sign-out: couldn't $name: $e");
      }
    }
  }
}
