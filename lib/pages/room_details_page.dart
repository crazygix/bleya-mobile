import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';
import '../providers/auth_providers.dart';
import '../providers/profile_providers.dart';
import '../platform/app_button.dart';
import '../platform/app_dialog.dart';
import '../platform/app_icon.dart';
import '../platform/app_route.dart';
import '../platform/app_sheet.dart';
import '../utils/app_errors.dart';
import '../utils/app_toast.dart';
import '../constants/theme.dart';
import '../widgets/app_skeleton.dart';
import '../widgets/app_spinner.dart';
import '../widgets/error_state.dart';
import '../widgets/glass_header.dart';
import '../widgets/liquid_glass_background.dart';
import '../widgets/empty_members_card.dart';
import '../widgets/members_section_header.dart';
import '../widgets/room_hero_card.dart';
import '../widgets/room_member_tile.dart';
import '../widgets/report_actions.dart';
import 'user_details_page.dart';

class RoomDetailsPage extends ConsumerStatefulWidget {
  final String roomId;
  final String roomName;
  final String? imageUrl;

  const RoomDetailsPage({
    super.key,
    required this.roomId,
    required this.roomName,
    this.imageUrl,
  });

  @override
  ConsumerState<RoomDetailsPage> createState() => _RoomDetailsPageState();
}

class _RoomDetailsPageState extends ConsumerState<RoomDetailsPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  bool _isLeaving = false;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // Members load fresh on every visit: roomMembersProvider is auto-disposed
    // when the page closes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entranceController.forward();
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  String _memberCountLabel(int count, {required bool hasMore}) {
    // Until the last page has loaded, the real count is higher.
    if (hasMore) return '$count+ members';
    if (count == 1) return '1 member';
    return '$count members';
  }

  String _resolveMembersError(Object error) {
    if (error is AppError) {
      return error.getUserMessage();
    }
    return "Couldn't load this room right now. Try again?";
  }

  String _cityFromRoomName(String roomName) {
    final parts = roomName
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return roomName.trim();
    return parts.first;
  }

  String _countryFromRoomName(String roomName) {
    final parts = roomName
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length < 2) return '';
    return parts.last;
  }

  Widget _buildStaggered({required int order, required Widget child}) {
    final start = (order * 0.07).clamp(0.0, 0.75).toDouble();
    final end = (start + 0.25).clamp(0.25, 1.0).toDouble();

    final animation = CurvedAnimation(
      parent: _entranceController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final value = animation.value;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 14),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _leaveCurrentRoom() async {
    final cityName = _cityFromRoomName(widget.roomName);
    final confirmed = await AppDialog.confirm(
      context,
      title: 'Leave $cityName?',
      message:
          "You'll leave this chat for now, but you can join again next time you visit",
      confirmText: 'Leave',
      destructive: true,
    );

    if (!confirmed || !mounted) return;

    setState(() => _isLeaving = true);
    try {
      await leaveRoom(ref, widget.roomId);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/home',
        ModalRoute.withName('/'),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is AppError
          ? error.getUserMessage()
          : "Couldn't leave that room. Try again?";
      AppToast.showError(context, message);
    } finally {
      if (mounted) {
        setState(() => _isLeaving = false);
      }
    }
  }

  Future<void> _showRoomActions() async {
    final selected = await AppSheet.actions<String>(
      context: context,
      actions: const [
        AppSheetAction<String>(value: 'report', label: 'Report room'),
        AppSheetAction<String>(
            value: 'leave', label: 'Leave room', isDestructive: true),
      ],
    );
    if (!mounted || selected == null) return;

    if (selected == 'report') {
      await showReportSheet(context: context, ref: ref, roomId: widget.roomId);
    } else if (selected == 'leave') {
      await _leaveCurrentRoom();
    }
  }

  void _openUserDetails(String userId) {
    Navigator.of(context).push(
      AppRoute.build(
        builder: (context) => UserDetailsPage(userId: userId),
      ),
    );
  }

  Widget _buildMembersLoadingSkeleton() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        BleyaTheme.contentPadding,
        BleyaTheme.spacingLG,
        BleyaTheme.contentPadding,
        BleyaTheme.spacing2XL,
      ),
      children: [
        const AppSkeleton(
          height: 220,
          borderRadius: BorderRadius.all(
            Radius.circular(BleyaTheme.radiusLarge),
          ),
        ),
        const SizedBox(height: BleyaTheme.spacingLG),
        const AppSkeleton(
          height: BleyaTheme.buttonHeight,
          borderRadius: BorderRadius.all(
            Radius.circular(BleyaTheme.radiusSmall),
          ),
        ),
        const SizedBox(height: BleyaTheme.spacingXL),
        const AppSkeleton(
          width: 120,
          height: 20,
        ),
        const SizedBox(height: BleyaTheme.spacingSM),
        ...List.generate(
          5,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: BleyaTheme.spacingSM),
            child: Container(
              padding: const EdgeInsets.all(BleyaTheme.radiusSmall),
              decoration: BoxDecoration(
                color: BleyaTheme.glassSurface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(BleyaTheme.radiusSmall),
                border: Border.all(
                  color: BleyaTheme.border.withValues(alpha: 0.3),
                  width: 1,
                ),
                boxShadow: BleyaTheme.glassShadow,
              ),
              child: const Row(
                children: [
                  AppSkeleton.circle(size: 48),
                  SizedBox(width: BleyaTheme.spacingMD),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSkeleton(width: 170, height: 16),
                        SizedBox(height: BleyaTheme.spacingXS),
                        AppSkeleton(width: 120, height: 12),
                      ],
                    ),
                  ),
                  SizedBox(width: BleyaTheme.spacingSM),
                  AppSkeleton(width: 16, height: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMembersContent(
    RoomMembersState membersState,
    String? currentUserId,
    String? currentUserBio,
  ) {
    final members = membersState.members;
    final memberCountLabel = _memberCountLabel(
      members.length,
      hasMore: membersState.hasMore,
    );
    final cityName = _cityFromRoomName(widget.roomName);
    final countryName = _countryFromRoomName(widget.roomName);
    final heroSubtitle = countryName;

    // Hero, section header, then the members (or the empty card), then a
    // spinner while more pages remain.
    const leadingItems = 2;
    final memberItems = members.isEmpty ? 1 : members.length;
    final itemCount =
        leadingItems + memberItems + (membersState.hasMore ? 1 : 0);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (membersState.hasMore && notification.metrics.extentAfter < 600) {
          ref.read(roomMembersProvider(widget.roomId).notifier).loadMore();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          BleyaTheme.contentPadding,
          BleyaTheme.spacingLG,
          BleyaTheme.contentPadding,
          BleyaTheme.spacing3XL,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: BleyaTheme.spacing2XL),
              child: _buildStaggered(
                order: 0,
                child: RoomHeroCard(
                  roomTitle: cityName,
                  roomSubtitle: heroSubtitle,
                  imageUrl: widget.imageUrl,
                ),
              ),
            );
          }
          if (index == 1) {
            return Padding(
              padding: const EdgeInsets.only(bottom: BleyaTheme.spacingSM),
              child: _buildStaggered(
                order: 1,
                child: MembersSectionHeader(
                  memberCountLabel: memberCountLabel,
                ),
              ),
            );
          }

          final memberIndex = index - leadingItems;
          if (members.isEmpty && memberIndex == 0) {
            return _buildStaggered(
              order: 2,
              child: const EmptyMembersCard(),
            );
          }
          if (memberIndex >= members.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: BleyaTheme.spacingLG),
              child: Center(child: AppSpinner()),
            );
          }

          final member = members[memberIndex];
          final isCurrentUser =
              currentUserId != null && member.id == currentUserId;
          final bioOverride = isCurrentUser && member.bio.trim().isEmpty
              ? currentUserBio
              : null;

          return _buildStaggered(
            order: 2 + memberIndex,
            child: Padding(
              padding: const EdgeInsets.only(bottom: BleyaTheme.spacingSM),
              child: RoomMemberTile(
                member: member,
                bioOverride: bioOverride,
                isCurrentUser: isCurrentUser,
                onTap: () => _openUserDetails(member.id),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(roomMembersProvider(widget.roomId));
    final currentUser = ref.watch(currentUserProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final currentUserId = currentUser?['id'] as String?;
    final currentUserBioFromAuth = currentUser?['bio'] as String?;
    final currentUserBio = profile?.bio ?? currentUserBioFromAuth;

    return Scaffold(
      backgroundColor: BleyaTheme.background,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const LiquidGlassBackground(),
          Column(
            children: [
              GlassHeader(
                rightAction: AppButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(
                    BleyaTheme.iconContainerSize,
                    BleyaTheme.iconContainerSize,
                  ),
                  onPressed: _isLeaving ? null : _showRoomActions,
                  child: Icon(
                    AppIcon.more(context),
                    size: 24,
                    color: _isLeaving
                        ? BleyaTheme.primary.withValues(alpha: 0.4)
                        : BleyaTheme.primary,
                  ),
                ),
                title: 'Info',
              ),
              Expanded(
                child: membersAsync.when(
                  data: (membersState) => _buildMembersContent(
                      membersState, currentUserId, currentUserBio),
                  loading: _buildMembersLoadingSkeleton,
                  error: (error, stack) => Center(
                    child: ErrorState(
                      title: "Couldn't load members",
                      description: _resolveMembersError(error),
                      onRetry: () {
                        ref.invalidate(roomMembersProvider(widget.roomId));
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
