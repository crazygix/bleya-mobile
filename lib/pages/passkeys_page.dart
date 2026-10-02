import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../constants/theme.dart';
import '../domain/entities/auth_result.dart';
import '../platform/app_button.dart';
import '../platform/app_dialog.dart';
import '../providers/auth_providers.dart';
import '../providers/use_case_providers.dart';
import '../utils/app_errors.dart';
import '../utils/app_toast.dart';
import '../utils/auth_error_messages.dart';
import '../widgets/app_skeleton.dart';
import '../widgets/error_state.dart';
import '../widgets/glass_header.dart';
import '../widgets/liquid_glass_background.dart';
import '../widgets/primary_button.dart';

/// Settings → Passkeys: list, add and delete the account's passkeys.
class PasskeysPage extends ConsumerStatefulWidget {
  const PasskeysPage({super.key});

  @override
  ConsumerState<PasskeysPage> createState() => _PasskeysPageState();
}

class _PasskeysPageState extends ConsumerState<PasskeysPage> {
  bool _isAdding = false;
  String? _deletingId;

  bool get _isBusy => _isAdding || _deletingId != null;

  void _refreshPasskeyState() {
    ref.invalidate(passkeysProvider);
    ref.invalidate(authSecurityStatusProvider);
    ref.invalidate(passkeySignInAvailableProvider);
  }

  Future<void> _addPasskey() async {
    setState(() => _isAdding = true);
    try {
      await ref.read(registerPasskeyUseCaseProvider)();
      if (!mounted) return;
      AppToast.showSuccess(context, 'Passkey added.');
    } catch (e) {
      if (!mounted) return;
      await _handleError(e, fallback: "Couldn't add a passkey. Try again?");
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
        _refreshPasskeyState();
      }
    }
  }

  Future<void> _deletePasskey(PasskeySummary passkey) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Delete passkey?',
      message: passkey.isSynced
          ? "You won't be able to sign in with it on any of your devices."
          : "You won't be able to sign in with it on this device.",
      confirmText: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _deletingId = passkey.id);
    try {
      await ref.read(deletePasskeyUseCaseProvider)(passkey.id);
      if (!mounted) return;
      AppToast.showInfo(context, 'Passkey deleted.');
    } catch (e) {
      if (!mounted) return;
      await _handleError(e,
          fallback: "Couldn't delete the passkey. Try again?");
    } finally {
      if (mounted) {
        setState(() => _deletingId = null);
        _refreshPasskeyState();
      }
    }
  }

  Future<void> _handleError(Object error, {required String fallback}) async {
    // Changing passkeys needs a sign-in from the last 30 minutes.
    if (error is AppError && error.code == AppErrorCode.forbidden) {
      await _offerSignInAgain(error.getUserMessage());
      return;
    }

    final message = authErrorMessage(error, fallback: fallback);
    if (message.isNotEmpty && mounted) {
      AppToast.showError(context, message);
    }
  }

  Future<void> _offerSignInAgain(String message) async {
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Sign in again',
      message: message,
      confirmText: 'Sign in again',
    );
    if (!confirmed || !mounted) return;
    await ref.read(logoutProvider)();
  }

  String _formatDate(DateTime date) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.yMMMd(locale).format(date);
  }

  String _passkeyDetails(PasskeySummary passkey) {
    final parts = <String>[
      if (passkey.createdAt != null) 'Added ${_formatDate(passkey.createdAt!)}',
      passkey.lastUsedAt != null
          ? 'Last used ${_formatDate(passkey.lastUsedAt!)}'
          : 'Not used yet',
    ];
    return parts.join(' · ');
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
        color:
            BleyaTheme.glassSurface.withValues(alpha: BleyaTheme.glassOpacity),
        borderRadius: BorderRadius.circular(BleyaTheme.radiusSmall),
        border: Border.all(
          color: BleyaTheme.border.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: BleyaTheme.glassShadow,
      );

  Widget _buildPasskeyTile(PasskeySummary passkey) {
    final isDeleting = _deletingId == passkey.id;

    return Container(
      padding: const EdgeInsets.all(BleyaTheme.spacingMD),
      decoration: _cardDecoration,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: BleyaTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.lock_shield,
              color: BleyaTheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: BleyaTheme.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  passkey.isSynced ? 'Synced passkey' : 'Passkey on one device',
                  style: BleyaTheme.listTitle.copyWith(
                    color: BleyaTheme.foreground,
                  ),
                ),
                const SizedBox(height: BleyaTheme.spacingXS),
                Text(
                  _passkeyDetails(passkey),
                  style: BleyaTheme.bodySmall.copyWith(
                    color: BleyaTheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: BleyaTheme.spacingSM),
          AppButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(
              BleyaTheme.iconContainerSize,
              BleyaTheme.iconContainerSize,
            ),
            onPressed: _isBusy ? null : () => _deletePasskey(passkey),
            child: isDeleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  )
                : Icon(
                    CupertinoIcons.trash,
                    size: 22,
                    color: _isBusy
                        ? BleyaTheme.error.withValues(alpha: 0.4)
                        : BleyaTheme.error,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<PasskeySummary> passkeys, bool canAdd) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        BleyaTheme.contentPadding,
        BleyaTheme.spacingLG,
        BleyaTheme.contentPadding,
        MediaQuery.of(context).padding.bottom + BleyaTheme.spacing2XL,
      ),
      children: [
        Text(
          'Passkeys let you sign in with your face, fingerprint or screen '
          'lock.',
          style: BleyaTheme.bodyMedium.copyWith(
            color: BleyaTheme.mutedForeground,
          ),
        ),
        const SizedBox(height: BleyaTheme.spacingXL),
        if (passkeys.isEmpty)
          Container(
            padding: const EdgeInsets.all(BleyaTheme.spacingLG),
            decoration: _cardDecoration,
            child: Text(
              "You haven't added a passkey yet.",
              style: BleyaTheme.bodyMedium.copyWith(
                color: BleyaTheme.mutedForeground,
              ),
              textAlign: TextAlign.center,
            ),
          )
        else
          for (final passkey in passkeys) ...[
            _buildPasskeyTile(passkey),
            const SizedBox(height: BleyaTheme.spacingSM),
          ],
        if (canAdd) ...[
          const SizedBox(height: BleyaTheme.spacingXL),
          PrimaryButton(
            text: 'Add a passkey',
            isLoading: _isAdding,
            isEnabled: !_isBusy,
            onPressed: _addPasskey,
          ),
        ],
      ],
    );
  }

  Widget _buildLoadingState() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        BleyaTheme.contentPadding,
        BleyaTheme.spacingLG,
        BleyaTheme.contentPadding,
        BleyaTheme.spacing2XL,
      ),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: BleyaTheme.spacingSM),
      itemBuilder: (context, index) => Container(
        padding: const EdgeInsets.all(BleyaTheme.spacingMD),
        decoration: _cardDecoration,
        child: const Row(
          children: [
            AppSkeleton.circle(size: 44),
            SizedBox(width: BleyaTheme.spacingMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeleton(width: 140, height: 16),
                  SizedBox(height: BleyaTheme.spacingXS),
                  AppSkeleton(width: 200, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final passkeysAsync = ref.watch(passkeysProvider);
    final canAdd =
        ref.watch(passkeyPlatformSupportedProvider).valueOrNull ?? false;

    return Scaffold(
      backgroundColor: BleyaTheme.background,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const LiquidGlassBackground(),
          Column(
            children: [
              const GlassHeader(title: 'Passkeys'),
              Expanded(
                child: passkeysAsync.when(
                  loading: _buildLoadingState,
                  error: (error, _) => Center(
                    child: ErrorState(
                      title: "Couldn't load passkeys",
                      description: error is AppError
                          ? error.getUserMessage()
                          : 'Something went wrong. Try again?',
                      onRetry: () => ref.invalidate(passkeysProvider),
                    ),
                  ),
                  data: (passkeys) => _buildContent(passkeys, canAdd),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
