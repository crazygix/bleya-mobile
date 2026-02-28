import 'package:flutter/cupertino.dart';
import '../constants/theme.dart';

class MembersSectionHeader extends StatelessWidget {
  final String memberCountLabel;

  const MembersSectionHeader({
    super.key,
    required this.memberCountLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Members',
          style: BleyaTheme.headingMedium.copyWith(
            fontSize: 30,
            height: 1.0,
          ),
        ),
        const SizedBox(width: BleyaTheme.spacingSM),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: BleyaTheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            memberCountLabel,
            style: BleyaTheme.bodySmall.copyWith(
              color: BleyaTheme.primaryDark,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}
