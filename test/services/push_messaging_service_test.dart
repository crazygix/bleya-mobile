import 'dart:async';

import 'package:bleya/services/push_messaging_service.dart';
import 'package:fake_async/fake_async.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes/in_memory_secure_storage.dart';

class MockFirebaseMessaging extends Mock implements FirebaseMessaging {}

/// Secure storage that fails every call, as a locked or broken keystore can.
class BrokenSecureStorage extends Fake implements FlutterSecureStorage {
  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw PlatformException(code: 'keystore');
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw PlatformException(code: 'keystore');
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw PlatformException(code: 'keystore');
  }
}

const _apnsTokenNotSet = 'apns-token-not-set';

FirebaseException _firebaseError(String code) {
  return FirebaseException(plugin: 'firebase_messaging', code: code);
}

const _deniedSettings = NotificationSettings(
  authorizationStatus: AuthorizationStatus.denied,
  alert: AppleNotificationSetting.notSupported,
  announcement: AppleNotificationSetting.notSupported,
  badge: AppleNotificationSetting.notSupported,
  carPlay: AppleNotificationSetting.notSupported,
  lockScreen: AppleNotificationSetting.notSupported,
  notificationCenter: AppleNotificationSetting.notSupported,
  showPreviews: AppleShowPreviewSetting.notSupported,
  sound: AppleNotificationSetting.notSupported,
  timeSensitive: AppleNotificationSetting.notSupported,
  criticalAlert: AppleNotificationSetting.notSupported,
  providesAppNotificationSettings: AppleNotificationSetting.notSupported,
);

void main() {
  late MockFirebaseMessaging messaging;
  late InMemorySecureStorage storage;
  late PushMessagingService service;

  setUp(() {
    messaging = MockFirebaseMessaging();
    storage = InMemorySecureStorage();
    service = PushMessagingService(storage: storage, messaging: messaging);
    when(() => messaging.deleteToken()).thenAnswer((_) async {});
    when(() => messaging.getToken()).thenAnswer((_) async => 'new-token');
  });

  bool deletionPending() =>
      storage.values[PushMessagingService.tokenDeletionPendingKey] == 'true';

  Future<void> markDeletionPending() => storage.write(
        key: PushMessagingService.tokenDeletionPendingKey,
        value: 'true',
      );

  group('getToken', () {
    test("reports iOS's missing APNs token as ApnsTokenNotReadyException",
        () async {
      when(() => messaging.getToken())
          .thenThrow(_firebaseError(_apnsTokenNotSet));

      await expectLater(
        service.getToken(),
        throwsA(isA<ApnsTokenNotReadyException>()),
      );
    });

    test('passes other errors on', () async {
      when(() => messaging.getToken()).thenThrow(_firebaseError('unknown'));

      await expectLater(service.getToken(), throwsA(isA<FirebaseException>()));
    });

    test('waits for a token deletion that is still running', () async {
      final deletion = Completer<void>();
      when(() => messaging.deleteToken()).thenAnswer((_) => deletion.future);

      unawaited(service.deleteTokenAfterSignOut());
      final token = service.getToken();
      await pumpEventQueue();
      verifyNever(() => messaging.getToken());

      deletion.complete();

      expect(await token, 'new-token');
      verifyInOrder([
        () => messaging.deleteToken(),
        () => messaging.getToken(),
      ]);
    });
  });

  group('deleteTokenAfterSignOut', () {
    test('deletes the FCM token and leaves nothing pending', () async {
      await service.deleteTokenAfterSignOut();

      verify(() => messaging.deleteToken()).called(1);
      expect(deletionPending(), isFalse);
    });

    test('a deletion that fails stays pending and never throws', () async {
      when(() => messaging.deleteToken()).thenThrow(_firebaseError('unknown'));

      await expectLater(service.deleteTokenAfterSignOut(), completes);

      expect(deletionPending(), isTrue);
    });

    test('stays pending while iOS has no APNs token', () async {
      when(() => messaging.deleteToken())
          .thenThrow(_firebaseError(_apnsTokenNotSet));

      await service.deleteTokenAfterSignOut();

      expect(deletionPending(), isTrue);
    });

    test('gives up after 10 s without an answer and stays pending', () {
      fakeAsync((async) {
        when(() => messaging.deleteToken())
            .thenAnswer((_) => Completer<void>().future);
        var done = false;

        service.deleteTokenAfterSignOut().then((_) => done = true);
        async.elapse(const Duration(seconds: 9));
        expect(done, isFalse);
        async.elapse(const Duration(seconds: 1));

        expect(done, isTrue);
        expect(deletionPending(), isTrue);
      });
    });

    test('still deletes the token when secure storage fails', () async {
      service = PushMessagingService(
        storage: BrokenSecureStorage(),
        messaging: messaging,
      );

      await expectLater(service.deleteTokenAfterSignOut(), completes);

      verify(() => messaging.deleteToken()).called(1);
    });
  });

  group('retryPendingTokenDeletion', () {
    test('deletes the token only when a deletion is pending', () async {
      await service.retryPendingTokenDeletion();
      verifyNever(() => messaging.deleteToken());

      await markDeletionPending();
      await service.retryPendingTokenDeletion();

      verify(() => messaging.deleteToken()).called(1);
      expect(deletionPending(), isFalse);
    });

    test('calls made while a deletion runs share it', () async {
      final deletion = Completer<void>();
      when(() => messaging.deleteToken()).thenAnswer((_) => deletion.future);

      final signOut = service.deleteTokenAfterSignOut();
      final retries = [
        service.retryPendingTokenDeletion(),
        service.retryPendingTokenDeletion(),
      ];
      deletion.complete();
      await Future.wait([signOut, ...retries]);

      verify(() => messaging.deleteToken()).called(1);
    });

    test('a cleared deletion is not retried', () async {
      await markDeletionPending();

      await service.clearPendingTokenDeletion();
      await service.retryPendingTokenDeletion();

      verifyNever(() => messaging.deleteToken());
    });
  });

  group('notification permission', () {
    test('asks for alerts, badges and sounds', () async {
      when(
        () => messaging.requestPermission(
          alert: any(named: 'alert'),
          badge: any(named: 'badge'),
          sound: any(named: 'sound'),
          provisional: any(named: 'provisional'),
        ),
      ).thenAnswer((_) async => _deniedSettings);

      await service.requestPermission();

      verify(
        () => messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        ),
      ).called(1);
    });

    test('remembers asking, and asking again, for the install', () async {
      expect(await service.hasRequestedPermission(), isFalse);
      expect(await service.hasRequestedPermissionAgain(), isFalse);

      await service.markPermissionRequested();
      expect(await service.hasRequestedPermission(), isTrue);
      expect(await service.hasRequestedPermissionAgain(), isFalse);

      await service.markPermissionRequestedAgain();
      expect(await service.hasRequestedPermissionAgain(), isTrue);
    });

    test('a storage failure reads as never asked and never throws', () async {
      service = PushMessagingService(
        storage: BrokenSecureStorage(),
        messaging: messaging,
      );

      expect(await service.hasRequestedPermission(), isFalse);
      await expectLater(service.markPermissionRequested(), completes);
      expect(await service.hasRequestedPermissionAgain(), isFalse);
      await expectLater(service.markPermissionRequestedAgain(), completes);
    });
  });
}
