import 'package:bleya/data/dtos/analytics_event_dto.dart';
import 'package:bleya/domain/entities/analytics_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final at = DateTime.fromMillisecondsSinceEpoch(1760000000000);

  test('app.opened carries only its time', () {
    expect(AnalyticsEventDto.toJson(AppOpened(occurredAt: at)), {
      'name': 'app.opened',
      'occurredAt': 1760000000000,
    });
  });

  test('sign-in events name the provider', () {
    expect(
      AnalyticsEventDto.toJson(
          SignInStarted(SignInMethod.google, occurredAt: at)),
      {
        'name': 'sign_in.started',
        'occurredAt': 1760000000000,
        'props': {'provider': 'google'},
      },
    );
    expect(
      AnalyticsEventDto.toJson(
          SignInCancelled(SignInMethod.passkey, occurredAt: at)),
      {
        'name': 'sign_in.cancelled',
        'occurredAt': 1760000000000,
        'props': {'provider': 'passkey'},
      },
    );
    expect(
      AnalyticsEventDto.toJson(SignInFailed(
        SignInMethod.apple,
        'apple:failed',
        occurredAt: at,
      )),
      {
        'name': 'sign_in.failed',
        'occurredAt': 1760000000000,
        'props': {'provider': 'apple', 'reason': 'apple:failed'},
      },
    );
  });

  test('a reason keeps to what the backend accepts', () {
    String reason(String value) => (AnalyticsEventDto.toJson(
          SignInFailed(SignInMethod.google, value, occurredAt: at),
        )['props'] as Map)['reason'] as String;

    expect(reason('platform:sign_in_failed'), 'platform:sign_in_failed');
    expect(reason('platform:ERR <bad> "x"'), 'platform:ERR _bad_ _x_');
    expect(reason(''), 'unknown');
    expect(reason('x' * 150), hasLength(100));
  });
}
