import '../entities/analytics_event.dart';

/// Sends product analytics events to the backend.
abstract class AnalyticsRepository {
  /// Queues [event] to be sent shortly, together with others. Never throws
  /// and never waits on the network: analytics must not get in the way.
  void record(AnalyticsEvent event);
}
