import 'package:bleya/services/app_badge_service.dart';

/// Records every count the app asks the app icon to show, instead of setting
/// it. [isSupported] tells the app whether it runs on an iPhone.
class FakeAppBadgeService extends AppBadgeService {
  FakeAppBadgeService({bool isSupported = true})
      : super(isSupported: isSupported);

  final List<int> counts = [];

  @override
  Future<void> setBadgeCount(int count) async {
    counts.add(count);
  }
}
