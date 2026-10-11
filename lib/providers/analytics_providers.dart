import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/analytics_event.dart';
import 'use_case_providers.dart';

/// Reports that the app opened. Read once, when the app starts (MyApp
/// watches it), so it counts cold starts.
final appOpenedProvider = Provider<void>((ref) {
  ref.read(recordAnalyticsEventUseCaseProvider)(AppOpened());
});
