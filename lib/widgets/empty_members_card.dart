import 'package:flutter/cupertino.dart';
import '../constants/theme.dart';

class EmptyMembersCard extends StatelessWidget {
  const EmptyMembersCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BleyaTheme.spacingXL),
      decoration: BoxDecoration(
        color: BleyaTheme.glassSurface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(BleyaTheme.radiusMedium),
        border: Border.all(
          color: BleyaTheme.border.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: BleyaTheme.glassShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            CupertinoIcons.person_2,
            size: 24,
            color: BleyaTheme.primary,
          ),
          const SizedBox(height: BleyaTheme.spacingSM),
          Text(
            'No members yet',
            style: BleyaTheme.listTitle,
          ),
          const SizedBox(height: BleyaTheme.spacingXS),
          Text(
            'Invite friends to get this room going.',
            style: BleyaTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
