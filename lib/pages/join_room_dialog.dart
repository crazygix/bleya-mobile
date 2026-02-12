import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/theme.dart';
import '../controllers/join_room_controller.dart';
import '../providers/chat_providers.dart';
import '../providers/controller_providers.dart';
import '../utils/app_errors.dart';
import '../widgets/app_skeleton.dart';
import '../widgets/app_spinner.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';

import '../widgets/primary_button.dart';
import '../widgets/profile_avatar.dart';

class JoinRoomDialog extends ConsumerStatefulWidget {
  const JoinRoomDialog({super.key});

  @override
  ConsumerState<JoinRoomDialog> createState() => _JoinRoomDialogState();
}

class _JoinRoomDialogState extends ConsumerState<JoinRoomDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSyncingSearchText = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);
  }

  void _onSearchChanged() {
    if (_isSyncingSearchText) {
      return;
    }

    final controller = ref.read(joinRoomControllerProvider.notifier);
    controller.onSearchQueryChanged(_searchController.text);
  }

  void _onSearchFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _syncSearchController(JoinRoomState joinState) {
    if (_searchController.text == joinState.searchQuery) {
      return;
    }

    _isSyncingSearchText = true;
    _searchController.value = TextEditingValue(
      text: joinState.searchQuery,
      selection: TextSelection.collapsed(offset: joinState.searchQuery.length),
    );
    _isSyncingSearchText = false;
  }

  void _clearSearch() {
    final controller = ref.read(joinRoomControllerProvider.notifier);
    controller.clearSearchQuery();
    _searchController.clear();
    _searchFocusNode.unfocus();
  }

  Future<void> _handleShareLocation() async {
    final controller = ref.read(joinRoomControllerProvider.notifier);
    await controller.shareLocationAndSearch();
  }

  Future<void> _fetchNearbyRooms() async {
    final controller = ref.read(joinRoomControllerProvider.notifier);
    await controller.fetchNearbyRooms();
  }

  Future<void> _joinRoom(Room room) async {
    final controller = ref.read(joinRoomControllerProvider.notifier);

    try {
      final messenger = ScaffoldMessenger.maybeOf(context);
      await controller.joinRoom(room);

      ref.invalidate(joinedRoomsFutureProvider);
      ref.invalidate(roomsListProvider);

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop();
      messenger?.showSnackBar(
        SnackBar(content: Text('You joined ${room.name}')),
      );
    } catch (e) {
      if (!mounted) return;

      final errorMessage =
          e is AppError ? e.getUserMessage() : "Something went off. Try again?";

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: BleyaTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final joinState = ref.watch(joinRoomControllerProvider);
    _syncSearchController(joinState);

    return Container(
      height: mediaQuery.size.height * 0.45,
      decoration: BoxDecoration(
        color: BleyaTheme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Expanded(child: _buildStepContent(joinState)),
        ],
      ),
    );
  }

  Widget _buildStepContent(JoinRoomState joinState) {
    switch (joinState.step) {
      case JoinRoomStep.initial:
        return _buildInitialStep();
      case JoinRoomStep.searching:
        return _buildSearchingStep();
      case JoinRoomStep.results:
        return _buildResultsStep(joinState);
    }
  }

  Widget _buildInitialStep() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.all(BleyaTheme.spacing3XL),
                child: Column(
                  children: [
                    const Spacer(),
                    Icon(
                      CupertinoIcons.compass,
                      size: 64,
                      color: BleyaTheme.primary,
                    ),
                    SizedBox(height: BleyaTheme.spacingXL),
                    Text(
                      'Explore around you',
                      style: BleyaTheme.headingMedium.copyWith(fontSize: 24),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: BleyaTheme.spacingMD),
                    Text(
                      'See what\'s happening around you and jump into the conversation.',
                      style: BleyaTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: BleyaTheme.spacing2XL),
                    const Spacer(),
                    PrimaryButton(
                      text: 'Search',
                      onPressed: _handleShareLocation,
                      trailingIcon: const Icon(
                        CupertinoIcons.search,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    SizedBox(
                      height: MediaQuery.of(context).padding.bottom +
                          BleyaTheme.spacingXS,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchingStep() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const AppSpinner(radius: 20),
          SizedBox(height: BleyaTheme.spacing2XL),
          Text(
            'Scouting for nearby chats...',
            style: BleyaTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRoomListSkeleton() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: BleyaTheme.contentPadding),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(bottom: BleyaTheme.spacingMD),
          child: Container(
            padding: EdgeInsets.all(BleyaTheme.spacingLG),
            decoration: BoxDecoration(
              color: BleyaTheme.glassSurface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(BleyaTheme.radiusMedium),
              border: Border.all(color: BleyaTheme.border, width: 1),
              boxShadow: BleyaTheme.glassShadow,
            ),
            child: const Row(
              children: [
                AppSkeleton.circle(size: 52),
                SizedBox(width: BleyaTheme.spacingLG),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSkeleton(width: 170, height: 16),
                      SizedBox(height: BleyaTheme.spacingXS),
                      AppSkeleton(width: 120, height: 14),
                    ],
                  ),
                ),
                SizedBox(width: BleyaTheme.spacingSM),
                AppSkeleton(width: 46, height: 26),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultsStep(JoinRoomState joinState) {
    final joinedRoomsAsync = ref.watch(joinedRoomsFutureProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(BleyaTheme.contentPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    CupertinoIcons.location,
                    size: 20,
                    color: BleyaTheme.primaryLight,
                  ),
                  SizedBox(width: BleyaTheme.spacingSM),
                  Text(
                    'Nearby chats',
                    style: BleyaTheme.headingMedium.copyWith(fontSize: 20),
                  ),
                ],
              ),
              SizedBox(height: BleyaTheme.spacingSM),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Jump into the conversation',
                      style: BleyaTheme.bodyMedium.copyWith(
                        color: BleyaTheme.mutedForeground,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(24, 24),
                    onPressed:
                        joinState.isSearchingNearby ? null : _fetchNearbyRooms,
                    child: Icon(
                      CupertinoIcons.arrow_clockwise,
                      size: 18,
                      color: BleyaTheme.primary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: BleyaTheme.spacingMD),
              _buildSearchField(joinState),
            ],
          ),
        ),
        if (joinState.isSearchingNearby)
          const LinearProgressIndicator(minHeight: 2)
        else
          const SizedBox(height: 2),
        Expanded(
          child: joinedRoomsAsync.when(
            data: (joinedRooms) {
              final availableRooms = joinState.nearbyRooms.where((room) {
                final joinedByList = joinedRooms.any((jr) => jr.id == room.id);
                return !room.isJoined && !joinedByList;
              }).toList()
                ..sort((a, b) {
                  final aDistance = a.distanceKm ?? 9999;
                  final bDistance = b.distanceKm ?? 9999;
                  return aDistance.compareTo(bDistance);
                });

              if (joinState.searchError != null) {
                return Padding(
                  padding: EdgeInsets.all(BleyaTheme.contentPadding),
                  child: ErrorState(
                    title: 'Couldn\'t find any chats',
                    description: joinState.searchError!,
                    onRetry: joinState.latitude != null &&
                            joinState.longitude != null
                        ? _fetchNearbyRooms
                        : _handleShareLocation,
                  ),
                );
              }

              if (joinState.nearbyRooms.isEmpty) {
                return EmptyState(
                  icon: CupertinoIcons.location_slash,
                  title: 'It\'s quiet around here',
                  description: 'We couldn\'t find any active chats nearby.',
                  actionText: 'Try again',
                  onAction: _fetchNearbyRooms,
                );
              }

              if (availableRooms.isEmpty) {
                final publicRoomCount =
                    joinedRooms.where((room) => room.type == 'public').length;

                return EmptyState(
                  icon: CupertinoIcons.checkmark_circle,
                  title: 'You\'ve found them all!',
                  description: publicRoomCount >= 5
                      ? 'You\'ve hit the limit of 5 chats.'
                      : 'You\'re already part of the local crowd.',
                );
              }

              return ListView.builder(
                padding:
                    EdgeInsets.symmetric(horizontal: BleyaTheme.contentPadding),
                itemCount: availableRooms.length,
                itemBuilder: (context, index) {
                  final room = availableRooms[index];
                  final isJoiningThis =
                      joinState.isJoining && joinState.joiningRoomId == room.id;
                  final distanceLabel = room.distanceKm != null
                      ? '${room.distanceKm!.toStringAsFixed(1)} km away'
                      : 'Close by';

                  return Padding(
                    padding: EdgeInsets.only(bottom: BleyaTheme.spacingMD),
                    child: GestureDetector(
                      onTap: joinState.isJoining ? null : () => _joinRoom(room),
                      child: Container(
                        padding: EdgeInsets.all(BleyaTheme.spacingLG),
                        decoration: BoxDecoration(
                          color:
                              BleyaTheme.glassSurface.withValues(alpha: 0.62),
                          borderRadius:
                              BorderRadius.circular(BleyaTheme.radiusMedium),
                          border: Border.all(
                            color: BleyaTheme.border,
                            width: 1,
                          ),
                          boxShadow: BleyaTheme.glassShadow,
                        ),
                        child: Row(
                          children: [
                            ProfileAvatar(
                              imageUrl: room.imageUrl,
                              size: 52,
                              backgroundColor: BleyaTheme.primaryLight,
                              fallbackIcon: CupertinoIcons.location,
                              fallbackIconColor: BleyaTheme.primaryDark,
                            ),
                            SizedBox(width: BleyaTheme.spacingLG),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    room.name,
                                    style: BleyaTheme.headingMedium.copyWith(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: BleyaTheme.spacingXS),
                                  Text(
                                    distanceLabel,
                                    style: BleyaTheme.bodyMedium.copyWith(
                                      fontSize: 14,
                                      color: BleyaTheme.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: BleyaTheme.spacingSM),
                            if (isJoiningThis)
                              const SizedBox(
                                width: 22,
                                height: 22,
                                child: AppSpinner(size: 22),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: BleyaTheme.primary
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Join',
                                  style: BleyaTheme.bodySmall.copyWith(
                                    color: BleyaTheme.primaryDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            loading: _buildRoomListSkeleton,
            error: (error, stack) {
              if (kDebugMode) {
                print('Error loading joined rooms: $error');
                print('Stack: $stack');
              }
              return Padding(
                padding: EdgeInsets.all(BleyaTheme.contentPadding),
                child: ErrorState(
                  title: 'Couldn\'t load your chats',
                  description: 'Try again in a moment.',
                  onRetry: () => ref.invalidate(joinedRoomsFutureProvider),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField(JoinRoomState joinState) {
    final borderColor = _searchFocusNode.hasFocus
        ? BleyaTheme.primary.withValues(alpha: 0.5)
        : BleyaTheme.border;

    return Container(
      decoration: BoxDecoration(
        color: BleyaTheme.glassSurface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(BleyaTheme.radiusMedium),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: BleyaTheme.glassShadow,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: BleyaTheme.spacingLG,
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.search,
            size: 18,
            color: BleyaTheme.mutedForeground,
          ),
          SizedBox(width: BleyaTheme.spacingMD),
          Expanded(
            child: CupertinoTextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              placeholder: 'Find a city...',
              decoration: const BoxDecoration(color: Colors.transparent),
              style: BleyaTheme.bodyMedium.copyWith(
                color: BleyaTheme.foreground,
                fontWeight: FontWeight.w600,
              ),
              placeholderStyle: BleyaTheme.bodyMedium.copyWith(
                color: BleyaTheme.mutedForeground.withValues(alpha: 0.7),
              ),
              padding: EdgeInsets.symmetric(
                vertical: BleyaTheme.spacingLG,
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
          if (joinState.searchQuery.isNotEmpty)
            GestureDetector(
              onTap: _clearSearch,
              child: Icon(
                CupertinoIcons.xmark_circle,
                size: 18,
                color: BleyaTheme.mutedForeground,
              ),
            ),
        ],
      ),
    );
  }
}
