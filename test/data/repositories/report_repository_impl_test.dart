import 'package:bleya/data/repositories/report_repository_impl.dart';
import 'package:bleya/domain/entities/report_reason.dart';
import 'package:bleya/utils/app_errors.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_http_adapter.dart';
import '../../fixtures/api_fixtures.dart';

void main() {
  late FakeHttpAdapter server;
  late ReportRepositoryImpl repository;

  setUp(() {
    server =
        FakeHttpAdapter((_) async => jsonResponse(201, reportCreatedJson()));
    repository = ReportRepositoryImpl(fakeDio(server));
  });

  test('POST /reports for a user sends the reason and the details', () async {
    await repository.createReport(
      reportedUserId: FixtureIds.otherUser,
      reason: ReportReason.harassment,
      details: 'Keeps messaging me after I asked them to stop.',
    );

    final request = server.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/reports');
    expect(request.data, {
      'reportedUserId': FixtureIds.otherUser,
      'reason': 'harassment',
      'details': 'Keeps messaging me after I asked them to stop.',
    });
  });

  test('a message report names only the message and its room', () async {
    await repository.createReport(
      messageId: FixtureIds.reply,
      roomId: FixtureIds.cityRoom,
      reason: ReportReason.underage,
    );

    expect(server.requests.single.data, {
      'roomId': FixtureIds.cityRoom,
      'messageId': FixtureIds.reply,
      'reason': 'underage',
    });
  });

  test('empty details are left out', () async {
    await repository.createReport(
      roomId: FixtureIds.cityRoom,
      reason: ReportReason.inappropriateContent,
      details: '',
    );

    expect(server.requests.single.data, {
      'roomId': FixtureIds.cityRoom,
      'reason': 'inappropriate_content',
    });
  });

  test('too many reports fail with the rate-limit reason', () async {
    server = FakeHttpAdapter(
      (_) async => apiErrorResponse(
        429,
        'TOO_MANY_REQUESTS',
        'Too many requests. Please try again later.',
      ),
    );
    repository = ReportRepositoryImpl(fakeDio(server));

    await expectLater(
      repository.createReport(
        reportedUserId: FixtureIds.otherUser,
        reason: ReportReason.spam,
      ),
      throwsA(
        isA<TooManyRequestsError>().having(
          (e) => e.getUserMessage(),
          'user message',
          'Too many requests. Please try again later.',
        ),
      ),
    );
  });
}
