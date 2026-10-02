import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/app_toast.dart';

/// Opens external web pages (Privacy, Terms, etc.) inside the app using a
/// modal in-app browser: SFSafariViewController on iOS, Chrome Custom Tabs on
/// Android. Both platforms get the same "browser sheet with a done/back
/// control" experience, and the user stays in the app.
///
/// The app handles no web links: it claims no bleyachat.com links (the iOS
/// entitlements list only `webcredentials`, for passkeys), and Flutter deep
/// linking is off on both platforms. A bleyachat.com page therefore opens as
/// a web page wherever it's tapped; the in-app browser is used so the user
/// stays in the app, not to work around link handling.
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
