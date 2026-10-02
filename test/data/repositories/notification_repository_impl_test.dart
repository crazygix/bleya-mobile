import 'package:bleya/data/repositories/notification_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_http_adapter.dart';

void main() {
  late FakeHttpAdapter server;
  late NotificationRepositoryImpl repository;

  setUp(() {
    server = FakeHttpAdapter((_) async => jsonResponse(200, {'success': true}));
    repository = NotificationRepositoryImpl(fakeDio(server));
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
}
