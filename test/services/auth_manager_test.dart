import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bleya/constants/urls.dart';
import 'package:bleya/providers/auth_providers.dart';
import 'package:bleya/services/auth_manager.dart';
import 'package:bleya/services/data_export_file.dart';
import 'package:bleya/services/push_messaging_service.dart';
import 'package:bleya/services/secure_cookie_storage.dart';
import 'package:bleya/services/socket_service.dart';
import 'package:bleya/utils/navigation.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes/fake_app_badge_service.dart';
import '../fakes/fake_http_adapter.dart';
import '../fakes/in_memory_secure_storage.dart';

class MockPushMessagingService extends Mock implements PushMessagingService {}

class MockSocketService extends Mock implements SocketService {}

/// An export that touches no files, for tests in fake time.
class _NoDataExportFile extends DataExportFile {
  @override
  Future<void> deleteAll() async {}
}

String _jwt({required String userId, required Duration expiresIn}) {
  String encode(Map<String, Object> part) =>
      base64Url.encode(utf8.encode(jsonEncode(part))).replaceAll('=', '');
  final exp = DateTime.now().add(expiresIn).millisecondsSinceEpoch ~/ 1000;
  return '${encode({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${encode({'userId': userId, 'exp': exp})}.signature';
}

/// `/auth/refresh` answered with a new access token and refresh cookie.
ResponseBody _refreshed(String token, {required String cookie}) {
  return ResponseBody.fromString(
    jsonEncode({'token': token}),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      HttpHeaders.setCookieHeader: ['refreshToken=$cookie; Path=/; HttpOnly'],
    },
  );
}

void main() {
  // Logout navigates through the app's navigator key.
  TestWidgetsFlutterBinding.ensureInitialized();

  final aliceToken = _jwt(userId: 'alice', expiresIn: const Duration(hours: 1));
  final aliceRefreshedToken =
      _jwt(userId: 'alice', expiresIn: const Duration(hours: 2));
  final apiUri = Uri.parse(ApiUrls.baseUrl);

  late Directory cookieDir;
  late Directory exportDir;
  late InMemorySecureStorage secureStorage;
  late MockSocketService socket;
  late MockPushMessagingService push;
  late FakeHttpAdapter cleanup;
  late FakeHttpHandler cleanupHandler;
  late FakeHttpAdapter api;
  late FakeHttpHandler apiHandler;
  late FakeAppBadgeService badge;
  late DataExportFile exportFile;

  setUp(() async {
    cookieDir = await Directory.systemTemp.createTemp('bleya-cookie-test');
    exportDir = await Directory.systemTemp.createTemp('bleya-export-test');
    secureStorage = InMemorySecureStorage();
    socket = MockSocketService();
    push = MockPushMessagingService();
    badge = FakeAppBadgeService();
    exportFile = DataExportFile(temporaryDirectory: () async => exportDir);
    cleanupHandler = (_) async => jsonResponse(200, {'success': true});
    cleanup = FakeHttpAdapter((options) => cleanupHandler(options));
    apiHandler = (_) async => jsonResponse(200, {'ok': true});
    api = FakeHttpAdapter((options) => apiHandler(options));

    when(() => socket.disconnect()).thenReturn(null);
    when(() => push.deleteTokenAfterSignOut()).thenAnswer((_) async {});

    // A signed-in device: the stored session, its refresh cookie and a
    // passkey for signing in.
    await secureStorage.write(key: 'auth_token', value: aliceToken);
    await secureStorage.write(key: 'has_registered_passkey', value: 'true');
    await PersistCookieJar(storage: SecureCookieStorage(secureStorage))
        .saveFromResponse(apiUri, [
      Cookie('refreshToken', 'refresh-1')..path = '/',
    ]);
  });

  tearDown(() async {
    await cookieDir.delete(recursive: true);
    await exportDir.delete(recursive: true);
  });

  ProviderContainer signedIn({DataExportFile? dataExportFile}) {
    final container = ProviderContainer(
      overrides: [
        tokenProvider.overrideWith((ref) => aliceToken),
        cookieStoragePathProvider.overrideWithValue(cookieDir.path),
        secureStorageProvider.overrideWithValue(secureStorage),
        socketServiceProvider.overrideWithValue(socket),
        pushMessagingServiceProvider.overrideWithValue(push),
        sessionCleanupDioProvider.overrideWithValue(fakeDio(cleanup)),
        dataExportFileProvider.overrideWithValue(dataExportFile ?? exportFile),
        appBadgeServiceProvider.overrideWithValue(badge),
      ],
    );
    addTearDown(container.dispose);
    container.read(dioProvider).httpClientAdapter = api;
    // Session-scoped providers follow the session while signed in.
    container.listen(sessionVersionProvider, (_, __) {});
    return container;
  }

  AuthManager authManager(ProviderContainer container) =>
      container.read(authManagerProvider);

  Future<List<Cookie>> storedCookies() {
    return PersistCookieJar(storage: SecureCookieStorage(secureStorage))
        .loadForRequest(apiUri);
  }

  group('logout', () {
    test('clears this device before the server calls finish', () async {
      cleanupHandler = (_) => Completer<ResponseBody>().future;
      when(() => push.deleteTokenAfterSignOut())
          .thenAnswer((_) => Completer<void>().future);
      final container = signedIn();
      final sessionBefore = container.read(sessionVersionProvider);

      await authManager(container).logout();

      expect(container.read(tokenProvider), isNull);
      expect(secureStorage.values['auth_token'], isNull);
      expect(await storedCookies(), isEmpty);
      verify(() => socket.disconnect()).called(1);
      // Clearing the token ends the session.
      expect(container.read(sessionVersionProvider), sessionBefore + 1);

      // The server calls went out, and nothing waited for them.
      await pumpEventQueue();
      expect(cleanup.callsTo('/auth/logout'), 1);
      verify(() => push.deleteTokenAfterSignOut()).called(1);
    });

    test('ends the session on the server with the cookie it captured',
        () async {
      final container = signedIn();

      await authManager(container).logout();
      await pumpEventQueue();

      final request = cleanup.requests.single;
      expect(request.path, '/auth/logout');
      expect(request.method, 'POST');
      expect(
          request.headers[HttpHeaders.cookieHeader], 'refreshToken=refresh-1');
      // The app's own client, with the cookie jar, sent nothing.
      expect(api.requests, isEmpty);
    });

    test("a refresh still running can't bring the session back", () async {
      final refreshAnswer = Completer<ResponseBody>();
      apiHandler = (options) => refreshAnswer.future;
      final container = signedIn();
      final manager = authManager(container);

      final refreshing = manager.refreshSession(container.read(dioProvider));
      await pumpEventQueue();
      expect(api.callsTo('/auth/refresh'), 1);

      await manager.logout();
      // The server answers after the sign-out, with a new session.
      refreshAnswer.complete(
        _refreshed(aliceRefreshedToken, cookie: 'refresh-2'),
      );
      await pumpEventQueue();

      expect(await refreshing, isA<RefreshUnavailable>());
      expect(container.read(tokenProvider), isNull);
      expect(secureStorage.values['auth_token'], isNull);
      expect(await storedCookies(), isEmpty);
      expect(
        cleanup.requests.single.headers[HttpHeaders.cookieHeader],
        'refreshToken=refresh-1',
      );
    });

    test('deletes the FCM token even when /auth/logout fails', () async {
      cleanupHandler = (options) async => throw connectionError(options);
      final container = signedIn();

      await authManager(container).logout();
      await pumpEventQueue();

      expect(cleanup.callsTo('/auth/logout'), 1);
      verify(() => push.deleteTokenAfterSignOut()).called(1);
    });

    test('without a session cookie, only deletes the FCM token', () async {
      await PersistCookieJar(storage: SecureCookieStorage(secureStorage))
          .deleteAll();
      final container = signedIn();

      await authManager(container).logout();
      await pumpEventQueue();

      expect(cleanup.requests, isEmpty);
      verify(() => push.deleteTokenAfterSignOut()).called(1);
    });

    test('a second logout while one runs does nothing more', () async {
      final container = signedIn();
      final manager = authManager(container);

      await Future.wait([manager.logout(), manager.logout()]);
      await pumpEventQueue();

      verify(() => socket.disconnect()).called(1);
      expect(cleanup.callsTo('/auth/logout'), 1);
      verify(() => push.deleteTokenAfterSignOut()).called(1);
      expect(badge.counts, [0]);
    });

    test('nothing refreshes while it runs', () async {
      final container = signedIn();
      final manager = authManager(container);

      final loggingOut = manager.logout();
      final refresh = await manager.refreshSession(container.read(dioProvider));
      await loggingOut;

      expect(refresh, isA<RefreshUnavailable>());
      expect(api.callsTo('/auth/refresh'), 0);
    });

    test('clears the app-icon badge', () async {
      final container = signedIn();

      await authManager(container).logout();

      expect(badge.counts, [0]);
    });

    test("deletes the data export, with Android's share copy", () async {
      final export = File('${exportDir.path}/${DataExportFile.fileName}');
      final shareCopy =
          File('${exportDir.path}/share_plus/${DataExportFile.fileName}');
      await export.create();
      await shareCopy.create(recursive: true);
      final container = signedIn();

      await authManager(container).logout();

      expect(await export.exists(), isFalse);
      expect(await shareCopy.exists(), isFalse);
    });

    test('keeps the passkey, so a returning user can sign in with it',
        () async {
      final container = signedIn();

      await authManager(container).logout();

      expect(secureStorage.values['has_registered_passkey'], 'true');
    });

    test('after deleting the account, forgets the passkey', () async {
      final container = signedIn();

      await authManager(container).logout(accountDeleted: true);

      expect(secureStorage.values['has_registered_passkey'], isNull);
    });

    test('an account deletion during a plain logout still forgets the passkey',
        () async {
      final container = signedIn();
      final manager = authManager(container);

      await Future.wait([
        manager.logout(),
        manager.logout(accountDeleted: true),
      ]);

      expect(secureStorage.values['has_registered_passkey'], isNull);
      verify(() => socket.disconnect()).called(1);
    });

    testWidgets('shows the intro without waiting for the server',
        (tester) async {
      cleanupHandler = (_) => Completer<ResponseBody>().future;
      when(() => push.deleteTokenAfterSignOut())
          .thenAnswer((_) => Completer<void>().future);
      final container = signedIn(dataExportFile: _NoDataExportFile());
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        routes: {
          '/': (_) => const Text('Intro'),
          '/home': (_) => const Text('Chats'),
        },
      ));
      unawaited(navigatorKey.currentState!.pushNamed('/home'));
      await tester.pumpAndSettle();
      expect(find.text('Chats'), findsOneWidget);

      await authManager(container).logout();
      await tester.pumpAndSettle();

      expect(find.text('Intro'), findsOneWidget);
      expect(find.text('Chats'), findsNothing);
      expect(navigatorKey.currentState!.canPop(), isFalse);
    });
  });

  group('endSession', () {
    test('signs out and keeps the reason for the sign-in screen', () async {
      final container = signedIn();

      await authManager(container)
          .endSession(message: 'Your account has been banned.');
      await pumpEventQueue();

      expect(container.read(tokenProvider), isNull);
      expect(
        container.read(fatalAuthMessageProvider),
        'Your account has been banned.',
      );
      verify(() => push.deleteTokenAfterSignOut()).called(1);
      expect(secureStorage.values['has_registered_passkey'], 'true');
    });
  });
}
