import 'package:bleya/data/repositories/analytics_repository_impl.dart';
import 'package:bleya/domain/entities/analytics_event.dart';
import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_http_adapter.dart';
import '../../fixtures/api_fixtures.dart';

void main() {
  late FakeHttpAdapter server;
  late AnalyticsRepositoryImpl repository;
  late Future<ResponseBody> Function(RequestOptions) answer;

  setUp(() {
    answer = (_) async => jsonResponse(202, analyticsEventsAcceptedJson());
    server = FakeHttpAdapter((options) => answer(options));
    repository = AnalyticsRepositoryImpl(fakeDio(server));
  });

  List<String> sentNames(RequestOptions request) => [
        for (final event in (request.data as Map)['events'] as List)
          (event as Map)['name'] as String,
      ];

  test('POST /analytics/events sends the events together, a moment later', () {
    fakeAsync((async) {
      repository.record(AppOpened());
      repository.record(SignInStarted(SignInMethod.google));
      async.elapse(const Duration(seconds: 1));
      expect(server.requests, isEmpty);

      async.elapse(const Duration(seconds: 1));

      final request = server.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/analytics/events');
      expect(sentNames(request), ['app.opened', 'sign_in.started']);
    });
  });

  test('sends at most 25 events per request', () {
    fakeAsync((async) {
      for (var i = 0; i < 30; i++) {
        repository.record(SignInStarted(SignInMethod.apple));
      }
      async.elapse(const Duration(seconds: 5));

      expect(
          server.requests.map((request) => sentNames(request).length), [25, 5]);
    });
  });

  test('offline: keeps the events and tries again later', () {
    fakeAsync((async) {
      var online = false;
      answer = (options) async {
        if (!online) throw connectionError(options);
        return jsonResponse(202, analyticsEventsAcceptedJson());
      };

      repository
          .record(SignInFailed(SignInMethod.google, 'network:networkError'));
      async.elapse(const Duration(seconds: 2));
      expect(server.requests, hasLength(1));

      online = true;
      async.elapse(const Duration(seconds: 30));

      expect(server.requests, hasLength(2));
      expect(sentNames(server.requests.last), ['sign_in.failed']);
    });
  });

  test('gives up after three retries until a new event comes', () {
    fakeAsync((async) {
      answer = (options) async =>
          apiErrorResponse(503, 'SERVICE_UNAVAILABLE', 'Down');

      repository.record(AppOpened());
      async.elapse(const Duration(minutes: 10));
      expect(server.requests, hasLength(4));

      repository.record(AppOpened());
      async.elapse(const Duration(seconds: 2));
      expect(server.requests, hasLength(5));
      expect(sentNames(server.requests.last), ['app.opened', 'app.opened']);
    });
  });

  test('drops a batch the backend refused as invalid', () {
    fakeAsync((async) {
      answer = (options) async =>
          apiErrorResponse(400, 'VALIDATION_ERROR', 'events must be an array.');

      repository.record(AppOpened());
      async.elapse(const Duration(minutes: 5));

      expect(server.requests, hasLength(1));
    });
  });

  test('never throws to the caller', () {
    fakeAsync((async) {
      answer = (options) async => throw StateError('boom');

      expect(() => repository.record(AppOpened()), returnsNormally);
      async.elapse(const Duration(seconds: 2));
      expect(server.requests, hasLength(1));
    });
  });
}
