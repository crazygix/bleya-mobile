import '../../domain/entities/analytics_event.dart';

/// An analytics event as POST /analytics/events takes it (the backend's
/// recordClientEvents in services/analyticsService.ts).
class AnalyticsEventDto {
  static const _maxReasonLength = 100;
  // The characters the backend accepts in a reason.
  static final _reasonDisallowed = RegExp(r'[^\w .:/-]');

  static Map<String, dynamic> toJson(AnalyticsEvent event) {
    final occurredAt = event.occurredAt.millisecondsSinceEpoch;
    return switch (event) {
      AppOpened() => {'name': 'app.opened', 'occurredAt': occurredAt},
      SignInStarted(:final method) => {
          'name': 'sign_in.started',
          'occurredAt': occurredAt,
          'props': {'provider': method.name},
        },
      SignInCancelled(:final method) => {
          'name': 'sign_in.cancelled',
          'occurredAt': occurredAt,
          'props': {'provider': method.name},
        },
      SignInFailed(:final method, :final reason) => {
          'name': 'sign_in.failed',
          'occurredAt': occurredAt,
          'props': {'provider': method.name, 'reason': _cleanReason(reason)},
        },
    };
  }

  static String _cleanReason(String reason) {
    final cleaned = reason.replaceAll(_reasonDisallowed, '_');
    if (cleaned.isEmpty) return 'unknown';
    return cleaned.length > _maxReasonLength
        ? cleaned.substring(0, _maxReasonLength)
        : cleaned;
  }
}
