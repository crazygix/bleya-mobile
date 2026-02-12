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
        SnackBar(content: Text('Successfully joined ${room.name}')),
      );
    } catch (e) {
      if (!mounted) return;

      final errorMessage = e is AppError
          ? e.getUserMessage()
          : "Something unexpected happened. Try again?";

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
      height: mediaQuery.size.height * 0.78,
      decoration: BoxDecoration(
        color: BleyaTheme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(BleyaTheme.contentPadding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Join a city room',
                    style: BleyaTheme.headingMedium.copyWith(fontSize: 24),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: BleyaTheme.glassSurface
                            .withValues(alpha: BleyaTheme.glassOpacity),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: BleyaTheme.border,
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        CupertinoIcons.xmark,
                        size: 16,
                        color: BleyaTheme.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: BleyaTheme.border),
            Expanded(child: _buildStepContent(joinState)),
          ],
        ),
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
    return Padding(
      padding: EdgeInsets.all(BleyaTheme.contentPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 124,
            height: 124,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  BleyaTheme.primaryLight,
                  BleyaTheme.primary.withValues(alpha: 0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              CupertinoIcons.location_solid,
              size: 56,
              color: BleyaTheme.primaryDark,
            ),
          ),
          SizedBox(height: BleyaTheme.spacing2XL),
          Text(
            'Discover nearby cities',
            style: BleyaTheme.headingMedium.copyWith(fontSize: 28),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: BleyaTheme.spacingMD),
          Text(
            'Share your location and we will show city rooms around you.',
            style: BleyaTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: BleyaTheme.spacingMD),
          Text(
            'Searching within ${JoinRoomController.fixedRadiusKm.toStringAsFixed(0)} km.',
            style: BleyaTheme.bodyMedium.copyWith(
              color: BleyaTheme.mutedForeground,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: BleyaTheme.spacing2XL),
          PrimaryButton(
            text: 'Share location',
            onPressed: _handleShareLocation,
            trailingIcon: const Icon(
              CupertinoIcons.location,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
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
            'Scanning nearby city rooms...',
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
                    CupertinoIcons.location_solid,
                    size: 20,
                    color: BleyaTheme.primary,
                  ),
                  SizedBox(width: BleyaTheme.spacingSM),
                  Text(
                    'Nearby city rooms',
                    style: BleyaTheme.headingMedium.copyWith(fontSize: 20),
                  ),
                ],
              ),
              SizedBox(height: BleyaTheme.spacingSM),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Within ${JoinRoomController.fixedRadiusKm.toStringAsFixed(0)} km of you',
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
                    title: 'Couldn\'t load nearby rooms',
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
                  title: 'No cities found nearby',
                  description: 'Try again from a different location.',
                  actionText: 'Search again',
                  onAction: _fetchNearbyRooms,
                );
              }

              if (availableRooms.isEmpty) {
                final publicRoomCount =
                    joinedRooms.where((room) => room.type == 'public').length;

                return EmptyState(
                  icon: CupertinoIcons.checkmark_circle,
                  title: 'No joinable city rooms',
                  description: publicRoomCount >= 5
                      ? 'You reached the limit of 5 group chats.'
                      : 'You already joined nearby cities.',
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
                      : 'Nearby';

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
                              fallbackIcon: CupertinoIcons.location_solid,
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
                  title: 'Error loading joined rooms',
                  description: 'Please try again.',
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
              placeholder: 'Search a city',
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
                CupertinoIcons.xmark_circle_fill,
                size: 18,
                color: BleyaTheme.mutedForeground,
              ),
            ),
        ],
      ),
    );
  }
}
