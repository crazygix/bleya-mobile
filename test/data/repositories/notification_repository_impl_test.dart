import 'package:bleya/data/repositories/notification_repository_impl.dart';
import 'package:bleya/utils/app_errors.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_http_adapter.dart';
import '../../fixtures/api_fixtures.dart';

void main() {
  late FakeHttpAdapter server;
  late NotificationRepositoryImpl repository;

  setUp(() {
    server = FakeHttpAdapter((_) async => jsonResponse(200, successJson()));
    repository = NotificationRepositoryImpl(fakeDio(server));
  });

  /// Answers requests with [handler] instead.
  void serve(FakeHttpHandler handler) {
    server = FakeHttpAdapter(handler);
    repository = NotificationRepositoryImpl(fakeDio(server));
  }

  group('fetchNotifications', () {
    test('GET /notifications pages back from a cursor', () async {
      serve((_) async => jsonResponse(
            200,
            notificationsPageJson(nextCursor: FixtureTimes.replied),
          ));

      final page = await repository.fetchNotifications(
        limit: 20,
        before: '1767272400000',
      );

      final request = server.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/notifications');
      expect(request.queryParameters, {
        'limit': 20,
        'before': '1767272400000',
      });
      expect(page.notifications.single.id, FixtureIds.notification);
      expect(page.unreadCount, 1);
      expect(page.nextCursor, '${FixtureTimes.replied}');
    });

    test('the first page is asked for without a query', () async {
      serve((_) async => jsonResponse(200, notificationsPageJson()));

      final page = await repository.fetchNotifications();

      expect(server.requests.single.queryParameters, isEmpty);
      expect(page.nextCursor, isNull);
    });

    test('tries once more after a dropped connection', () async {
      var calls = 0;
      serve((options) async {
        calls++;
        if (calls == 1) throw connectionError(options);
        return jsonResponse(200, notificationsPageJson());
      });

      final page = await repository.fetchNotifications();

      expect(server.callsTo('/notifications'), 2);
      expect(page.notifications, hasLength(1));
    });

    test('offline twice: fails with a network error', () async {
      serve((options) async => throw connectionError(options));

      await expectLater(
        repository.fetchNotifications(),
        throwsA(isA<NetworkError>()),
      );
      expect(server.callsTo('/notifications'), 2);
    });

    test('a server error fails at once, without a retry', () async {
      serve((_) async => apiErrorResponse(
            500,
            'INTERNAL_ERROR',
            'Something went wrong on our end. Please try again in a bit.',
          ));

      await expectLater(
        repository.fetchNotifications(),
        throwsA(isA<ServerError>()),
      );
      expect(server.callsTo('/notifications'), 1);
    });
  });

  group('registerPushToken', () {
    test('asks for badge counts in pushes when the app keeps the badge',
        () async {
      await repository.registerPushToken(
        token: 'fcm-token',
        platform: 'ios',
        badge: true,
      );

      final request = server.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/notifications/push/register');
      expect(request.data, {
        'token': 'fcm-token',
        'platform': 'ios',
        'badge': true,
      });
    });

    test('sends no badge field otherwise, as builds before it did', () async {
      await repository.registerPushToken(
        token: 'fcm-token',
        platform: 'android',
      );

      expect(server.requests.single.data, {
        'token': 'fcm-token',
        'platform': 'android',
      });
    });
  });

  test('POST /notifications/:id/read', () async {
    await repository.markAsRead(FixtureIds.notification);

    final request = server.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/notifications/${FixtureIds.notification}/read');
    expect(request.data, isNull);
  });

  test('POST /notifications/read-all', () async {
    await repository.markAllAsRead();

    final request = server.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/notifications/read-all');
  });

  test('POST /notifications/:id/dismiss', () async {
    await repository.dismissNotification(FixtureIds.notification);

    final request = server.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/notifications/${FixtureIds.notification}/dismiss');
  });

  test('POST /notifications/dismiss-all', () async {
    await repository.dismissAll();

    final request = server.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/notifications/dismiss-all');
  });
}
