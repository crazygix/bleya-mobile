import 'dart:io';

import 'package:bleya/services/push_messaging_service.dart';
import 'package:bleya/services/secure_cookie_storage.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/in_memory_secure_storage.dart';

void main() {
  late Directory basePath;
  late InMemorySecureStorage secureStorage;

  setUp(() async {
    basePath = await Directory.systemTemp.createTemp('bleya-session-test');
    secureStorage = InMemorySecureStorage();
  });

  tearDown(() async {
    if (await basePath.exists()) {
      await basePath.delete(recursive: true);
    }
  });

  File marker() =>
      File('${basePath.path}/${SessionStorageMigration.markerFileName}');

  Future<void> writeLegacyCookieFile(String name, String contents) async {
    final file = File('${basePath.path}/cookies/ie0_ps1/$name');
    await file.create(recursive: true);
    await file.writeAsString(contents);
  }

  group('SecureCookieStorage', () {
    test('round-trips cookies through a new jar, kept on this device only',
        () async {
      final uri = Uri.parse('https://api.bleyachat.com/v1/auth/refresh');
      final refreshCookie = Cookie('refreshToken', 'secret')
        ..path = '/'
        ..expires = DateTime.now().add(const Duration(days: 30));

      await PersistCookieJar(storage: SecureCookieStorage(secureStorage))
          .saveFromResponse(uri, [refreshCookie]);
      final loaded =
          await PersistCookieJar(storage: SecureCookieStorage(secureStorage))
              .loadForRequest(uri);

      expect(loaded.single.value, 'secret');
      expect(
        secureStorage.accessibilityByKey.values,
        everyElement('first_unlock_this_device'),
      );
    });

    test('deleteAll removes every stored cookie key', () async {
      final uri = Uri.parse('https://api.bleyachat.com/v1/auth/refresh');
      final jar = PersistCookieJar(storage: SecureCookieStorage(secureStorage));
      await jar.saveFromResponse(uri, [Cookie('refreshToken', 'secret')]);

      await jar.deleteAll();

      expect(
        secureStorage.values.keys
            .where((key) => key.startsWith(SecureCookieStorage.keyPrefix)),
        isEmpty,
      );
    });
  });

  group('SessionStorageMigration', () {
    test('moves legacy cookie files into secure storage on upgrade', () async {
      await writeLegacyCookieFile('.index', '["api.bleyachat.com"]');
      await writeLegacyCookieFile('.domains', '{}');
      await writeLegacyCookieFile('api.bleyachat.com', '{"/":{}}');
      await secureStorage.write(key: 'auth_token', value: 'current-session');

      await SessionStorageMigration.run(
        basePath: basePath.path,
        secureStorage: secureStorage,
      );

      expect(
          secureStorage.values['cookie_jar:.index'], '["api.bleyachat.com"]');
      expect(secureStorage.values['cookie_jar:api.bleyachat.com'], '{"/":{}}');
      expect(secureStorage.values['auth_token'], 'current-session');
      expect(
        SessionStorageMigration.usesLegacyCookieFiles(basePath.path),
        isFalse,
      );
      expect(await marker().exists(), isTrue);
    });

    test('clears a session left in the Keychain on a fresh install', () async {
      await secureStorage.write(key: 'auth_token', value: 'old-install');
      await PersistCookieJar(storage: SecureCookieStorage(secureStorage))
          .saveFromResponse(
        Uri.parse('https://api.bleyachat.com/'),
        [Cookie('refreshToken', 'old-refresh')],
      );
      await secureStorage.write(key: 'has_registered_passkey', value: 'true');
      // The old install's sign-out never managed to delete its push token.
      // Left pending, it would delete the new install's token.
      await secureStorage.write(
        key: PushMessagingService.tokenDeletionPendingKey,
        value: 'true',
      );

      await SessionStorageMigration.run(
        basePath: basePath.path,
        secureStorage: secureStorage,
      );

      expect(secureStorage.values.keys, ['has_registered_passkey']);
      expect(await marker().exists(), isTrue);
    });

    test('leaves the session alone on later launches', () async {
      await SessionStorageMigration.run(
        basePath: basePath.path,
        secureStorage: secureStorage,
      );
      await secureStorage.write(key: 'auth_token', value: 'new-session');

      await SessionStorageMigration.run(
        basePath: basePath.path,
        secureStorage: secureStorage,
      );

      expect(secureStorage.values['auth_token'], 'new-session');
    });
  });
}
