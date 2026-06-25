import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/app_toast.dart';

/// Opens external web pages (Privacy, Terms, etc.) inside the app using a
/// modal in-app browser: SFSafariViewController on iOS, Chrome Custom Tabs on
/// Android. Both platforms get the same "browser sheet with a done/back
/// control" experience.
///
/// We intentionally avoid [LaunchMode.externalApplication]. On iOS that mode
/// hands the URL to the OS, which then matches bleyachat.com against our
/// associated domains (`applinks:bleyachat.com`) and re-opens the app as a
/// universal link — with no deep-link handler that bounces into a launch loop
/// (and can surface the prod app from a dev build). Loading the page inside an
/// in-app browser sidesteps universal-link routing entirely.
class AppBrowser {
  static Future<void> open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    var opened = false;
    if (uri != null) {
      opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    }
    if (!opened && context.mounted) {
      AppToast.showError(context, "Couldn't open the link.");
    }
  }
}
