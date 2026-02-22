import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/theme.dart';
import '../controllers/join_room_controller.dart';
import '../domain/entities/city.dart';
import '../providers/chat_providers.dart';
import '../providers/controller_providers.dart';
import '../utils/app_errors.dart';
import '../utils/app_toast.dart';
import '../widgets/app_skeleton.dart';
import '../widgets/app_spinner.dart';

import '../widgets/compact_state_view.dart';
import '../widgets/nearby_city_item.dart';

class JoinRoomDialog extends ConsumerStatefulWidget {
  const JoinRoomDialog({super.key});

  @override
  ConsumerState<JoinRoomDialog> createState() => _JoinRoomDialogState();
}

class _JoinRoomDialogState extends ConsumerState<JoinRoomDialog>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final joinState = ref.read(joinRoomControllerProvider);
      // Check if we were stuck on a permission error or "open settings" state
      if (joinState.isLocationPermDeniedForever ||
          (joinState.searchError != null &&
              joinState.searchError!.contains('settings'))) {
        _handleShareLocation();
      }
    }
  }

  Future<void> _handleShareLocation() async {
    final controller = ref.read(joinRoomControllerProvider.notifier);
    await controller.shareLocationAndSearch();
  }

  Future<void> _fetchNearbyCities() async {
    final controller = ref.read(joinRoomControllerProvider.notifier);
    await controller.fetchNearbyCities();
  }

  Future<void> _joinCity(City city) async {
    final controller = ref.read(joinRoomControllerProvider.notifier);

    try {
      await controller.joinCity(city);

      ref.invalidate(joinedRoomsFutureProvider);
      ref.invalidate(roomsListProvider);

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop();
      AppToast.showSuccess(
        context,
        'You joined ${city.name}, ${city.countryName}',
      );
    } catch (e) {
      if (!mounted) return;

      final errorMessage =
          e is AppError ? e.getUserMessage() : "Something went off. Try again?";

      AppToast.showError(context, errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final joinState = ref.watch(joinRoomControllerProvider);
    // Pre-load joined rooms so the results step doesn't flash a skeleton
    ref.watch(joinedRoomsFutureProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: mediaQuery.size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: BleyaTheme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: _buildStepContent(joinState)),
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

  // Helper to enforce consistent height across Initial, Searching, Error, and Empty states
  Widget _buildUniformCompactState(CompactStateView content) {
    return SingleChildScrollView(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Invisible template (Initial State) to force height
          Opacity(
            opacity: 0.0,
            child: CompactStateView(
              icon: CupertinoIcons.map,
              title: 'Find your city',
              description: 'See who\'s hanging out nearby and say hello.',
              buttonText: 'Search',
              onAction: () {},
            ),
          ),
          // Visible content
          content,
        ],
      ),
    );
  }

  Widget _buildInitialStep() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Initial step IS the template, so we don't need the wrapper,
        // but using it updates the "Reference" validation if we wanted.
        // However, for simplicity and performance, just return the view.
        // The wrapper is for states that MIGHT be smaller.
        return SingleChildScrollView(
          child: CompactStateView(
            icon: CupertinoIcons.map,
            title: 'Find your city',
            description: 'See who\'s hanging out nearby and say hello.',
            buttonText: 'Search',
            onAction: _handleShareLocation,
            trailingActionIcon: const Icon(
              CupertinoIcons.search,
              color: Colors.white,
              size: 20,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchingStep() {
    return _buildUniformCompactState(
      CompactStateView(
        customIcon: const SizedBox(
          height: 64,
          width: 64,
          child: Center(
            child: AppSpinner(radius: 20),
          ),
        ),
        title: '',
        description: 'Looking for nearby chats...',
      ),
    );
  }

  Widget _buildRoomListSkeleton() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: BleyaTheme.contentPadding),
      shrinkWrap: true,
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
    if (joinState.isLocationPermDeniedForever) {
      return _buildUniformCompactState(
        CompactStateView(
          title: 'Where are you?',
          description: joinState.searchError ??
              'We need your location to find nearby chats. Check your settings?',
          buttonText: 'Open Settings',
          onAction: () {
            ref
                .read(joinRoomControllerProvider.notifier)
                .openLocationSettings();
          },
        ),
      );
    }

    if (joinState.searchError != null) {
      return _buildUniformCompactState(
        CompactStateView(
          title: 'Nothing around',
          description: joinState.searchError!,
          onAction: joinState.latitude != null && joinState.longitude != null
              ? _fetchNearbyCities
              : _handleShareLocation,
        ),
      );
    }

    // Remove LinearProgressIndicator
    final joinedRoomsAsync = ref.watch(joinedRoomsFutureProvider);

    return joinedRoomsAsync.when(
      data: (joinedRooms) {
        final nearbyCities = joinState.nearbyCities;

        if (nearbyCities.isEmpty) {
          return _buildUniformCompactState(
            CompactStateView(
              title: 'It\'s quiet here',
              description: 'No cities nearby yet.',
              icon: CupertinoIcons.compass,
              onAction: _fetchNearbyCities,
            ),
          );
        }

        // We restrict the list height to 70% of the screen so it scrolls if content is larger.
        final maxHeight = MediaQuery.of(context).size.height * 0.7;
        final bottomPadding = MediaQuery.of(context).padding.bottom;

        return Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  BleyaTheme.contentPadding,
                  BleyaTheme.spacingLG,
                  BleyaTheme.contentPadding,
                  BleyaTheme.spacingSM,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Nearby',
                    style: BleyaTheme.headingMedium.copyWith(fontSize: 20),
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  padding: EdgeInsets.only(
                    left: BleyaTheme.contentPadding,
                    right: BleyaTheme.contentPadding,
                    bottom: bottomPadding + BleyaTheme.spacingLG,
                  ),
                  shrinkWrap: true,
                  itemCount: nearbyCities.length,
                  itemBuilder: (context, index) {
                    final city = nearbyCities[index];
                    final isJoiningThis = joinState.isJoining &&
                        joinState.joiningCityId == city.id;

                    return NearbyCityItem(
                      city: city,
                      isJoining: isJoiningThis,
                      onJoin:
                          joinState.isJoining ? null : () => _joinCity(city),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: _buildRoomListSkeleton,
      error: (error, stack) {
        if (kDebugMode) {
          print('Error loading joined rooms: $error');
          print('Stack: $stack');
        }
        return _buildUniformCompactState(
          CompactStateView(
            title: 'Couldn\'t load your chats',
            description: 'Try again in a moment.',
            onAction: () => ref.invalidate(joinedRoomsFutureProvider),
          ),
        );
      },
    );
  }
}
