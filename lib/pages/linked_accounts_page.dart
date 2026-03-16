import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/theme.dart';
import '../controllers/auth_controller.dart';
import '../domain/entities/auth_result.dart';
import '../providers/auth_providers.dart';
import '../providers/controller_providers.dart';
import '../utils/app_toast.dart';
import '../widgets/app_navigation_bar.dart';
import '../widgets/liquid_glass_background.dart';
import '../widgets/settings_menu_item.dart';

class LinkedAccountsPage extends ConsumerWidget {
  const LinkedAccountsPage({super.key});

  Future<void> _handleLink(
    BuildContext context,
    WidgetRef ref,
    AuthProvider provider,
  ) async {
    final result = await ref
        .read(authControllerProvider.notifier)
        .linkProvider(provider);

    if (result == null || !context.mounted) {
      return;
    }

    ref.invalidate(authSecurityStatusProvider);
    AppToast.showSuccess(
      context,
      '${provider.label} linked.',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final securityAsync = ref.watch(authSecurityStatusProvider);

    return Scaffold(
      backgroundColor: BleyaTheme.background,
      body: Stack(
        children: [
          const LiquidGlassBackground(),
          SafeArea(
            child: Column(
              children: [
                const AppNavigationBar(title: 'Linked Accounts'),
                Expanded(
                  child: securityAsync.when(
                    data: (status) {
                      return ListView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: BleyaTheme.contentPadding,
                        ),
                        children: [
                          Text(
                            'Keep more than one trusted way in.',
                            style: BleyaTheme.headingMedium.copyWith(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Link both Apple and Google so you always have a fallback before we add stricter recovery controls later.',
                            style: BleyaTheme.bodyLarge,
                          ),
                          const SizedBox(height: BleyaTheme.spacing2XL),
                          for (final provider in AuthProvider.values) ...[
                            _LinkedProviderCard(
                              provider: provider,
                              status: status,
                              isLoading: authState.activeAction ==
                                  (provider == AuthProvider.apple
                                      ? AuthAction.linkApple
                                      : AuthAction.linkGoogle),
                              onLink: () => _handleLink(context, ref, provider),
                            ),
                            const SizedBox(height: BleyaTheme.spacingMD),
                          ],
                          if (authState.errorMessage != null &&
                              authState.errorMessage!.isNotEmpty) ...[
                            const SizedBox(height: BleyaTheme.spacingLG),
                            Text(
                              authState.errorMessage!,
                              style: BleyaTheme.bodyMedium.copyWith(
                                color: BleyaTheme.error,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (error, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: BleyaTheme.contentPadding,
                        ),
                        child: Text(
                          "Couldn't load your linked accounts right now.",
                          style: BleyaTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkedProviderCard extends StatelessWidget {
  final AuthProvider provider;
  final AuthSecurityStatus status;
  final bool isLoading;
  final VoidCallback onLink;

  const _LinkedProviderCard({
    required this.provider,
    required this.status,
    required this.isLoading,
    required this.onLink,
  });

  @override
  Widget build(BuildContext context) {
    final linked = status.linkedProviders
        .where((identity) => identity.provider == provider)
        .toList(growable: false);
    final isLinked = linked.isNotEmpty;
    final email = linked.isNotEmpty ? linked.first.email : null;

    return Container(
      padding: const EdgeInsets.all(BleyaTheme.cardPadding),
      decoration: BoxDecoration(
        color: BleyaTheme.glassSurface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(BleyaTheme.radiusMedium),
        border: Border.all(color: BleyaTheme.border),
        boxShadow: BleyaTheme.glassShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                provider == AuthProvider.apple
                    ? Icons.apple
                    : CupertinoIcons.globe,
                size: 22,
                color: BleyaTheme.foreground,
              ),
              const SizedBox(width: BleyaTheme.spacingSM),
              Expanded(
                child: Text(
                  provider.label,
                  style: BleyaTheme.bodyLarge.copyWith(
                    color: BleyaTheme.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StatusChip(
                label: isLinked ? 'Linked' : 'Available',
                color: isLinked ? BleyaTheme.success : BleyaTheme.primary,
              ),
            ],
          ),
          const SizedBox(height: BleyaTheme.spacingMD),
          Text(
            isLinked
                ? (email != null && email.isNotEmpty
                    ? email
                    : 'Linked to this account')
                : 'Add ${provider.label} as another trusted sign-in method.',
            style: BleyaTheme.bodyMedium,
          ),
          if (!isLinked) ...[
            const SizedBox(height: BleyaTheme.spacingMD),
            SettingsMenuItem(
              icon: provider == AuthProvider.apple
                  ? CupertinoIcons.link
                  : CupertinoIcons.link,
              iconColor: BleyaTheme.primary,
              label: isLoading ? 'Linking...' : 'Link ${provider.label}',
              onTap: isLoading ? () {} : onLink,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: BleyaTheme.bodySmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
