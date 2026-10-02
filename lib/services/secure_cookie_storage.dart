import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'push_messaging_service.dart';

/// Cookie jar storage backed by the platform keystore (Keychain on iOS,
/// Keystore-encrypted preferences on Android) instead of plain files, because
/// the jar holds the long-lived refresh token.
class SecureCookieStorage implements Storage {
  SecureCookieStorage(this._storage);

  static const keyPrefix = 'cookie_jar:';

  // "This device only" keeps the cookie out of backups restored onto another
  // device; "after first unlock" still allows a refresh while the phone is
  // locked. Reads, writes and deletes must all use the same options, because
  // the Keychain matches deletes on accessibility.
  static const iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  final FlutterSecureStorage _storage;

  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async {}

  @override
  Future<String?> read(String key) {
    return _storage.read(key: '$keyPrefix$key', iOptions: iosOptions);
  }

  @override
  Future<void> write(String key, String value) {
    return _storage.write(
      key: '$keyPrefix$key',
      value: value,
      iOptions: iosOptions,
    );
  }

  @override
  Future<void> delete(String key) {
    return _storage.delete(key: '$keyPrefix$key', iOptions: iosOptions);
  }

  @override
  Future<void> deleteAll(List<String> keys) async {
    for (final key in keys) {
      await delete(key);
    }
  }
}

/// One-time session storage housekeeping, run before anything reads the
/// stored session.
///
/// - Upgrade from a build that kept cookies in plain files: the files are
///   copied into [SecureCookieStorage] and deleted, so the user stays signed
///   in. If that fails, the files stay and are used until a later launch
///   manages the move (see [usesLegacyCookieFiles]).
/// - Fresh install: iOS keeps Keychain items after an app is deleted, so a
///   reinstalled app would start inside the old session. It is cleared,
///   together with a push token deletion the old install left pending, which
///   would otherwise delete the new install's token.
class SessionStorageMigration {
  // Written once per install. Its absence (with no legacy cookie folder) is
  // what identifies a fresh install.
  static const markerFileName = '.secure_session_v1';

  static const _authTokenKey = 'auth_token';

  // cookie_jar's FileStorage folder for PersistCookieJar's defaults
  // (ignoreExpires: false, persistSession: true).
  static const _legacyJarFolder = 'ie0_ps1';

  static String legacyCookieFolder(String basePath) => '$basePath/cookies';

  /// Whether the cookie jar still has to read the old plain files because
  /// the move into secure storage hasn't completed.
  static bool usesLegacyCookieFiles(String basePath) {
    return Directory(legacyCookieFolder(basePath)).existsSync();
  }

  static Future<void> run({
    required String basePath,
    required FlutterSecureStorage secureStorage,
  }) async {
    final marker = File('$basePath/$markerFileName');
    final legacyFolder = Directory(legacyCookieFolder(basePath));

    try {
      if (await legacyFolder.exists()) {
        await _moveLegacyCookies(legacyFolder, secureStorage);
        await _writeMarker(marker);
        return;
      }

      if (await marker.exists()) {
        return;
      }

      // Record the install before clearing anything. Without the marker, the
      // next launch would take the new session for a leftover and clear it.
      if (!await _writeMarker(marker)) {
        return;
      }
      await _clearLeftoverSession(secureStorage);
    } catch (e) {
      if (kDebugMode) {
        print('Session storage migration failed: $e');
      }
    }
  }

  static Future<void> _moveLegacyCookies(
    Directory legacyFolder,
    FlutterSecureStorage secureStorage,
  ) async {
    final jarFolder = Directory('${legacyFolder.path}/$_legacyJarFolder');
    if (await jarFolder.exists()) {
      final target = SecureCookieStorage(secureStorage);
      await for (final entity in jarFolder.list(followLinks: false)) {
        if (entity is! File) continue;
        // FileStorage names each file after its key (a host, `.index`, ...).
        final key = entity.path.substring(jarFolder.path.length + 1);
        await target.write(key, await entity.readAsString());
      }
    }
    // Only reached once every cookie is in secure storage.
    await legacyFolder.delete(recursive: true);
  }

  static Future<bool> _writeMarker(File marker) async {
    try {
      await marker.create(recursive: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _clearLeftoverSession(
    FlutterSecureStorage secureStorage,
  ) async {
    await secureStorage.delete(key: _authTokenKey);
    await PersistCookieJar(storage: SecureCookieStorage(secureStorage))
        .deleteAll();
    await secureStorage.delete(
      key: PushMessagingService.tokenDeletionPendingKey,
    );
  }
}
