import 'package:bleya/domain/entities/analytics_event.dart';
import 'package:bleya/use_cases/analytics/record_analytics_event_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks.dart';

void main() {
  late MockAnalyticsRepository repository;

  setUpAll(() {
    registerFallbackValue(AppOpened());
  });

  setUp(() {
    repository = MockAnalyticsRepository();
    when(() => repository.record(any())).thenReturn(null);
  });

  test('RecordAnalyticsEventUseCase hands the event to the repository', () {
    final event = SignInStarted(SignInMethod.passkey);

    RecordAnalyticsEventUseCase(repository)(event);

    verify(() => repository.record(event)).called(1);
  });
}
