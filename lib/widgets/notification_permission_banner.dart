import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/theme.dart';
import '../providers/controller_providers.dart';

/// Dismissable banner shown when system notifications are disabled, prompting
/// the user to enable them. Self-hides when notifications are authorized or the
/// banner has been dismissed. Its button shows Android's system dialog once
/// more when Android still allows it, and opens the app's settings otherwise.
class NotificationPermissionBanner extends ConsumerWidget {
  const NotificationPermissionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show = ref.watch(
      pushNotificationsControllerProvider
          .select((state) => state.showNotificationsBanner),
    );

    if (!show) {
      return const SizedBox.shrink();
    }

    final asksAgain = ref.watch(
      pushNotificationsControllerProvider
          .select((state) => state.canRequestPermissionAgain),
    );

    final controller = ref.read(pushNotificationsControllerProvider.notifier);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        BleyaTheme.contentPadding,
        0,
        BleyaTheme.contentPadding,
        BleyaTheme.spacingMD,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: BleyaTheme.glassSurface
              .withValues(alpha: BleyaTheme.glassOpacity),
          borderRadius: BorderRadius.circular(BleyaTheme.radiusLarge),
          border: Border.all(color: BleyaTheme.border, width: 1),
          boxShadow: BleyaTheme.glassShadow,
        ),
        child: Padding(
          padding: EdgeInsets.all(BleyaTheme.spacingMD),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: BleyaTheme.primaryLight,
                  borderRadius: BorderRadius.circular(BleyaTheme.radiusMedium),
                ),
                child: Icon(
                  CupertinoIcons.bell_slash_fill,
                  color: BleyaTheme.primary,
                  size: 20,
                ),
              ),
              SizedBox(width: BleyaTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notifications are off',
                      style: BleyaTheme.bodyMedium.copyWith(
                        color: BleyaTheme.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: BleyaTheme.spacingXS),
                    Text(
                      "Turn them on so you don't miss new messages.",
                      style: BleyaTheme.bodySmall,
                    ),
                    SizedBox(height: BleyaTheme.spacingSM),
                    GestureDetector(
                      onTap: controller.turnOnNotifications,
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            asksAgain ? 'Turn on' : 'Open Settings',
                            style: BleyaTheme.bodyMedium.copyWith(
                              color: BleyaTheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          // Settings opens outside the app.
                          if (!asksAgain) ...[
                            SizedBox(width: BleyaTheme.spacingXS),
                            Icon(
                              CupertinoIcons.arrow_up_right,
                              color: BleyaTheme.primary,
                              size: 14,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: controller.dismissNotificationsBanner,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.all(BleyaTheme.spacingXS),
                  child: Icon(
                    CupertinoIcons.xmark,
                    color: BleyaTheme.mutedForeground,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
