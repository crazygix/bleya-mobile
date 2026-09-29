import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bleya/domain/repositories/auth_repository.dart';
import 'package:bleya/providers/auth_providers.dart';
import 'package:bleya/providers/repository_providers.dart';
import 'package:bleya/services/auth_manager.dart';
import 'package:bleya/services/push_messaging_service.dart';
import 'package:bleya/services/socket_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes/in_memory_secure_storage.dart';

class MockSocketService extends Mock implements SocketService {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockPushMessagingService extends Mock implements PushMessagingService {}

typedef _Handler = Future<ResponseBody> Function(RequestOptions options);

/// Answers requests from [handler] instead of the network.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final _Handler handler;
  final List<RequestOptions> requests = [];

  int callsTo(String path) => requests.where((r) => r.path == path).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int statusCode, Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

ResponseBody _apiError(int statusCode, String code, String message) {
  return _json(statusCode, {
    'error': {'code': code, 'message': message},
  });
}

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

  setUp(() async {
    storageDir = await Directory.systemTemp.createTemp('bleya-dio-test');
    secureStorage = InMemorySecureStorage();
    socketService = MockSocketService();
    authRepository = MockAuthRepository();
    pushMessagingService = MockPushMessagingService();

    when(() => socketService.disconnect()).thenReturn(null);
    when(() => authRepository.logout()).thenAnswer((_) async {});
    when(() => pushMessagingService.getToken()).thenAnswer((_) async => null);
  });

  tearDown(() async {
    await storageDir.delete(recursive: true);
  });

  ({ProviderContainer container, Dio dio, _FakeAdapter adapter}) setUpDio({
    required String token,
    required _Handler handler,
  }) {
    final container = ProviderContainer(
      overrides: [
        tokenProvider.overrideWith((ref) => token),
        cookieStoragePathProvider.overrideWithValue(storageDir.path),
        secureStorageProvider.overrideWithValue(secureStorage),
        socketServiceProvider.overrideWithValue(socketService),
        authRepositoryProvider.overrideWithValue(authRepository),
        pushMessagingServiceProvider.overrideWithValue(pushMessagingService),
      ],
    );
    addTearDown(container.dispose);

    final adapter = _FakeAdapter(handler);
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
      if (auth == 'Bearer $freshToken') return _json(200, {'ok': true});
      return _apiError(401, 'UNAUTHORIZED', 'Invalid token');
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
            () async => _apiError(status, 'ERROR', 'Try again later'),
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
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
              error: const SocketException('offline'),
            );
          }
          return _apiError(401, 'UNAUTHORIZED', 'Invalid token');
        },
      );

      final error = await setup.dio.get('/rooms/joined').then<DioException?>(
          (_) => null,
          onError: (Object e) => e as DioException);

      expect(error?.type, DioExceptionType.connectionError);
      expect(setup.container.read(tokenProvider), validToken);
      verifyNever(() => socketService.disconnect());
    });
  });

  group('an ended session signs out', () {
    test('a ban signs out and keeps the reason for the sign-in screen',
        () async {
      final setup = setUpDio(
        token: validToken,
        handler: expiredSession(
          () async => _apiError(
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
    });

    test('a rejected refresh token signs out without a message', () async {
      final setup = setUpDio(
        token: validToken,
        handler: expiredSession(
          () async => _apiError(401, 'UNAUTHORIZED', 'Invalid refresh token'),
        ),
      );

      await expectLater(
        setup.dio.get('/rooms/joined'),
        throwsA(isA<DioException>()),
      );

      expect(setup.container.read(tokenProvider), isNull);
      expect(setup.container.read(fatalAuthMessageProvider), isNull);
    });

    test('a ban found by the early refresh blocks the request', () async {
      final setup = setUpDio(
        token: expiredToken,
        handler: (options) async {
          if (options.path == '/auth/refresh') {
            return _apiError(403, 'USER_BLOCKED', 'Suspended until Monday.');
          }
          return _json(200, {'ok': true});
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
        handler: expiredSession(() async => _json(200, {'token': freshToken})),
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
          return _json(200, {'token': freshToken});
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
