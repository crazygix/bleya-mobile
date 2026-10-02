import 'dart:convert';
import 'dart:io';

import 'package:bleya/constants/urls.dart';
import 'package:bleya/domain/repositories/auth_repository.dart';
import 'package:bleya/providers/auth_providers.dart';
import 'package:bleya/providers/repository_providers.dart';
import 'package:bleya/services/auth_manager.dart';
import 'package:bleya/services/data_export_file.dart';
import 'package:bleya/services/push_messaging_service.dart';
import 'package:bleya/services/secure_cookie_storage.dart';
import 'package:bleya/services/socket_service.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes/fake_app_badge_service.dart';
import '../fakes/fake_http_adapter.dart';
import '../fakes/in_memory_secure_storage.dart';

class MockSocketService extends Mock implements SocketService {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockPushMessagingService extends Mock implements PushMessagingService {}

String _jwt({required Duration expiresIn}) {
  String encode(Map<String, dynamic> part) =>
      base64Url.encode(utf8.encode(jsonEncode(part))).replaceAll('=', '');
  final exp = DateTime.now().add(expiresIn).millisecondsSinceEpoch ~/ 1000;
  return '${encode({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${encode({'userId': 'user-1', 'exp': exp})}.signature';
}

void main() {
  // Logout navigates through the app's navigator key.
  TestWidgetsFlutterBinding.ensureInitialized();

  final validToken = _jwt(expiresIn: const Duration(hours: 1));
  final expiredToken = _jwt(expiresIn: const Duration(minutes: -1));
  final freshToken = _jwt(expiresIn: const Duration(hours: 2));

  late Directory storageDir;
  late InMemorySecureStorage secureStorage;
  late MockSocketService socketService;
  late MockAuthRepository authRepository;
  late MockPushMessagingService pushMessagingService;
  late FakeHttpAdapter sessionCleanup;

  setUp(() async {
    storageDir = await Directory.systemTemp.createTemp('bleya-dio-test');
    secureStorage = InMemorySecureStorage();
    socketService = MockSocketService();
    authRepository = MockAuthRepository();
    pushMessagingService = MockPushMessagingService();
    sessionCleanup = FakeHttpAdapter(
      (_) async => jsonResponse(200, {'success': true}),
    );

    when(() => socketService.disconnect()).thenReturn(null);
    when(() => pushMessagingService.deleteTokenAfterSignOut())
        .thenAnswer((_) async {});
    // The session's refresh cookie.
    await PersistCookieJar(storage: SecureCookieStorage(secureStorage))
        .saveFromResponse(Uri.parse(ApiUrls.baseUrl), [
      Cookie('refreshToken', 'refresh-1')..path = '/',
    ]);
  });

  /// Whether the cookie jar still holds a session.
  Future<bool> hasSessionCookie() async {
    final cookies =
        await PersistCookieJar(storage: SecureCookieStorage(secureStorage))
            .loadForRequest(Uri.parse(ApiUrls.baseUrl));
    return cookies.isNotEmpty;
  }

  tearDown(() async {
    await storageDir.delete(recursive: true);
  });

  ({ProviderContainer container, Dio dio, FakeHttpAdapter adapter}) setUpDio({
    required String token,
    required FakeHttpHandler handler,
  }) {
    final container = ProviderContainer(
      overrides: [
        tokenProvider.overrideWith((ref) => token),
        cookieStoragePathProvider.overrideWithValue(storageDir.path),
        secureStorageProvider.overrideWithValue(secureStorage),
        socketServiceProvider.overrideWithValue(socketService),
        authRepositoryProvider.overrideWithValue(authRepository),
        pushMessagingServiceProvider.overrideWithValue(pushMessagingService),
        sessionCleanupDioProvider.overrideWithValue(fakeDio(sessionCleanup)),
        dataExportFileProvider.overrideWithValue(
          DataExportFile(temporaryDirectory: () async => storageDir),
        ),
        appBadgeServiceProvider.overrideWithValue(FakeAppBadgeService()),
      ],
    );
    addTearDown(container.dispose);

    final adapter = FakeHttpAdapter(handler);
    final dio = container.read(dioProvider)..httpClientAdapter = adapter;
    return (container: container, dio: dio, adapter: adapter);
  }

  // An API call that fails with 401 until retried with the fresh token.
  Future<ResponseBody> Function(RequestOptions) expiredSession(
    Future<ResponseBody> Function() refreshResponse,
  ) {
    return (options) async {
      if (options.path == '/auth/refresh') return refreshResponse();
      final auth = options.headers['Authorization'];
      if (auth == 'Bearer $freshToken') return jsonResponse(200, {'ok': true});
      return apiErrorResponse(401, 'UNAUTHORIZED', 'Invalid token');
    };
  }

  group('temporary refresh failures keep the session', () {
    for (final (label, status) in [
      ('rate limit', 429),
      ('server error', 500),
      ('outage', 503),
    ]) {
      test('$label: fails the request with the $status, not a 401', () async {
        final setup = setUpDio(
          token: validToken,
          handler: expiredSession(
            () async => apiErrorResponse(status, 'ERROR', 'Try again later'),
          ),
        );

        final error = await setup.dio.get('/rooms/joined').then<DioException?>(
            (_) => null,
            onError: (Object e) => e as DioException);

        expect(error?.response?.statusCode, status);
        expect(setup.container.read(tokenProvider), validToken);
        verifyNever(() => socketService.disconnect());
      });
    }

    test('offline: fails with a connection error, still signed in', () async {
      final setup = setUpDio(
        token: validToken,
        handler: (options) async {
          if (options.path == '/auth/refresh') {
            throw connectionError(options);
          }
          return apiErrorResponse(401, 'UNAUTHORIZED', 'Invalid token');
        },
      );

      final error = await setup.dio.get('/rooms/joined').then<DioException?>(
          (_) => null,
          onError: (Object e) => e as DioException);

      expect(error?.type, DioExceptionType.connectionError);
      expect(setup.container.read(tokenProvider), validToken);
      verifyNever(() => socketService.disconnect());
      expect(await hasSessionCookie(), isTrue);
      verifyNever(() => pushMessagingService.deleteTokenAfterSignOut());
    });
  });

  group('an ended session signs out', () {
    test('a ban signs out and keeps the reason for the sign-in screen',
        () async {
      final setup = setUpDio(
        token: validToken,
        handler: expiredSession(
          () async => apiErrorResponse(
            403,
            'USER_BLOCKED',
            'This account has been banned.',
          ),
        ),
      );

      await expectLater(
        setup.dio.get('/rooms/joined'),
        throwsA(isA<DioException>()),
      );

      expect(setup.container.read(tokenProvider), isNull);
      expect(
        setup.container.read(fatalAuthMessageProvider),
        'This account has been banned.',
      );
      verify(() => socketService.disconnect()).called(1);
      // The same sign-out as a logout: nothing of the session stays, and
      // the account's pushes stop.
      expect(await hasSessionCookie(), isFalse);
      await pumpEventQueue();
      verify(() => pushMessagingService.deleteTokenAfterSignOut()).called(1);
    });

    test('a rejected refresh token signs out without a message', () async {
      final setup = setUpDio(
        token: validToken,
        handler: expiredSession(
          () async =>
              apiErrorResponse(401, 'UNAUTHORIZED', 'Invalid refresh token'),
        ),
      );

      await expectLater(
        setup.dio.get('/rooms/joined'),
        throwsA(isA<DioException>()),
      );

      expect(setup.container.read(tokenProvider), isNull);
      expect(setup.container.read(fatalAuthMessageProvider), isNull);
      expect(secureStorage.values['auth_token'], isNull);
      expect(await hasSessionCookie(), isFalse);
      await pumpEventQueue();
      verify(() => pushMessagingService.deleteTokenAfterSignOut()).called(1);
    });

    test('a ban found by the early refresh blocks the request', () async {
      final setup = setUpDio(
        token: expiredToken,
        handler: (options) async {
          if (options.path == '/auth/refresh') {
            return apiErrorResponse(
                403, 'USER_BLOCKED', 'Suspended until Monday.');
          }
          return jsonResponse(200, {'ok': true});
        },
      );

      await expectLater(
        setup.dio.get('/rooms/joined'),
        throwsA(isA<DioException>()),
      );

      expect(setup.adapter.callsTo('/rooms/joined'), 0);
      expect(setup.container.read(tokenProvider), isNull);
      expect(
        setup.container.read(fatalAuthMessageProvider),
        'Suspended until Monday.',
      );
    });
  });

  group('a successful refresh', () {
    test('retries the request once with the new token', () async {
      final setup = setUpDio(
        token: validToken,
        handler: expiredSession(
            () async => jsonResponse(200, {'token': freshToken})),
      );

      final response = await setup.dio.get('/rooms/joined');

      expect(response.statusCode, 200);
      expect(setup.container.read(tokenProvider), freshToken);
      expect(secureStorage.values['auth_token'], freshToken);
      expect(setup.adapter.callsTo('/rooms/joined'), 2);
    });

    test('is shared by requests that fail at the same time', () async {
      final setup = setUpDio(
        token: validToken,
        handler: expiredSession(() async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return jsonResponse(200, {'token': freshToken});
        }),
      );

      await Future.wait([
        setup.dio.get('/rooms/joined'),
        setup.dio.get('/notifications'),
      ]);

      expect(setup.adapter.callsTo('/auth/refresh'), 1);
    });
  });

  group('AuthManager.classifyRefreshFailure', () {
    DioException failure(int? statusCode, [Object? body]) {
      final options = RequestOptions(path: '/auth/refresh');
      return DioException(
        requestOptions: options,
        type: statusCode == null
            ? DioExceptionType.connectionTimeout
            : DioExceptionType.badResponse,
        response: statusCode == null
            ? null
            : Response(
                requestOptions: options,
                statusCode: statusCode,
                data: body,
              ),
      );
    }

    test('only 401 and 403 end the session', () {
      expect(AuthManager.classifyRefreshFailure(failure(401)),
          isA<SessionEnded>());
      expect(AuthManager.classifyRefreshFailure(failure(403)),
          isA<SessionEnded>());
      for (final status in [400, 404, 429, 500, 502, 503]) {
        expect(AuthManager.classifyRefreshFailure(failure(status)),
            isA<RefreshUnavailable>(),
            reason: '$status');
      }
      expect(AuthManager.classifyRefreshFailure(failure(null)),
          isA<RefreshUnavailable>());
    });

    test('keeps the server message of a 403', () {
      final result = AuthManager.classifyRefreshFailure(failure(403, {
        'error': {'code': 'USER_BLOCKED', 'message': ' Banned for spam. '},
      }));

      expect((result as SessionEnded).message, 'Banned for spam.');
    });
  });
}
