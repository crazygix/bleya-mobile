import 'dart:async';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/dtos/push_notification_payload_dto.dart';
import '../domain/entities/push_notification_payload.dart';

/// iOS hasn't received this device's APNs token yet, so there is no FCM
/// token to get or delete. It usually arrives within seconds of launch.
class ApnsTokenNotReadyException implements Exception {
  const ApnsTokenNotReadyException();

  @override
  String toString() =>
      'ApnsTokenNotReadyException: iOS has not received the APNs token yet';
}

class PushMessagingService {
  /// Set while this device's FCM token still has to be deleted after a
  /// sign-out, so a deletion that failed is tried again later.
  static const tokenDeletionPendingKey = 'push_token_deletion_pending';

  /// Set once the app has asked for notification permission. It belongs to
  /// the install, so signing out keeps it.
  static const _permissionRequestedKey = 'push_permission_requested';

  /// Set once the "Notifications are off" banner has used the one extra
  /// system dialog Android allows after a refusal.
  static const _permissionRequestedAgainKey = 'push_permission_requested_again';

  static const _tokenDeletionTimeout = Duration(seconds: 10);

  final FirebaseMessaging _messaging;
  final FlutterSecureStorage _storage;
  Future<PushNotificationPayload?>? _initialPayloadFuture;

  /// The token deletion that is running, if any. getToken waits for it, so
  /// a new session never registers the token being deleted.
  Future<void>? _tokenDeletion;

  PushMessagingService({
    required FlutterSecureStorage storage,
    FirebaseMessaging? messaging,
  })  : _storage = storage,
        _messaging = messaging ?? FirebaseMessaging.instance;

  Future<NotificationSettings> getNotificationSettings() {
    return _messaging.getNotificationSettings();
  }

  Future<NotificationSettings> requestPermission() {
    return _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  /// Whether the app has asked for notification permission on this install.
  Future<bool> hasRequestedPermission() => _readFlag(_permissionRequestedKey);

  Future<void> markPermissionRequested() => _writeFlag(_permissionRequestedKey);

  /// Whether the banner has used Android's one extra permission dialog.
  Future<bool> hasRequestedPermissionAgain() =>
      _readFlag(_permissionRequestedAgainKey);

  Future<void> markPermissionRequestedAgain() =>
      _writeFlag(_permissionRequestedAgainKey);

  /// This device's FCM token, once a token deletion that is still running
  /// has finished. Throws [ApnsTokenNotReadyException] while iOS hasn't
  /// received the APNs token.
  Future<String?> getToken() async {
    final deletion = _tokenDeletion;
    if (deletion != null) {
      await deletion;
    }
    try {
      return await _messaging.getToken();
    } on FirebaseException catch (error) {
      if (_isApnsTokenNotSet(error)) {
        throw const ApnsTokenNotReadyException();
      }
      rethrow;
    }
  }

  /// Deletes this device's FCM token after a sign-out, so the previous
  /// account's pushes stop arriving. Until it succeeds, a flag in secure
  /// storage keeps it pending for [retryPendingTokenDeletion]. Never throws.
  Future<void> deleteTokenAfterSignOut() {
    return _runTokenDeletion(() async {
      await _writeFlag(tokenDeletionPendingKey);
      await _deleteToken();
    });
  }

  /// Finishes a token deletion that didn't go through after an earlier
  /// sign-out. Does nothing when none is pending. Calls made while a deletion
  /// runs share it. Never throws.
  Future<void> retryPendingTokenDeletion() {
    final running = _tokenDeletion;
    if (running != null) {
      return running;
    }
    return _runTokenDeletion(() async {
      if (!await _readFlag(tokenDeletionPendingKey)) {
        return;
      }
      await _deleteToken();
    });
  }

  /// Drops a pending token deletion, e.g. once the token is registered for
  /// a new session.
  Future<void> clearPendingTokenDeletion() =>
      _deleteFlag(tokenDeletionPendingKey);

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  Stream<PushNotificationPayload> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp
          .map(_parsePayload)
          .where((payload) => payload != null)
          .cast<PushNotificationPayload>();

  Future<PushNotificationPayload?> getInitialPayload() {
    return _initialPayloadFuture ??=
        _messaging.getInitialMessage().then(_parsePayload);
  }

  /// Runs [deletion] after any deletion already running. The returned future
  /// is set as [_tokenDeletion] before this returns, so a getToken call made
  /// right after waits for it.
  Future<void> _runTokenDeletion(Future<void> Function() deletion) {
    final previous = _tokenDeletion;
    final done = Completer<void>();
    _tokenDeletion = done.future;
    unawaited(() async {
      try {
        if (previous != null) {
          await previous;
        }
        await deletion();
      } catch (error) {
        // Still pending: tried again at the next launch, return to the app
        // or reconnect while signed out.
        debugPrint('push/delete-token failed: $error');
      } finally {
        if (identical(_tokenDeletion, done.future)) {
          _tokenDeletion = null;
        }
        done.complete();
      }
    }());
    return done.future;
  }

  Future<void> _deleteToken() async {
    try {
      await _messaging.deleteToken().timeout(_tokenDeletionTimeout);
    } on FirebaseException catch (error) {
      if (_isApnsTokenNotSet(error)) {
        throw const ApnsTokenNotReadyException();
      }
      rethrow;
    }
    await _deleteFlag(tokenDeletionPendingKey);
  }

  static bool _isApnsTokenNotSet(FirebaseException error) {
    return error.plugin == 'firebase_messaging' &&
        error.code == 'apns-token-not-set';
  }

  Future<bool> _readFlag(String key) async {
    try {
      return await _storage.read(key: key) == 'true';
    } catch (error) {
      debugPrint('push/storage: reading $key failed: $error');
      return false;
    }
  }

  Future<void> _writeFlag(String key) async {
    try {
      await _storage.write(key: key, value: 'true');
    } catch (error) {
      debugPrint('push/storage: writing $key failed: $error');
    }
  }

  Future<void> _deleteFlag(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (error) {
      debugPrint('push/storage: deleting $key failed: $error');
    }
  }

  PushNotificationPayload? _parsePayload(RemoteMessage? message) {
    if (message == null || message.data.isEmpty) {
      return null;
    }

    try {
      return PushNotificationPayloadDto.fromJson(
        Map<String, dynamic>.from(message.data),
      );
    } on FormatException {
      return null;
    }
  }
}
