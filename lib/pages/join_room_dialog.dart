import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../providers/chat_providers.dart';
import '../providers/auth_providers.dart';
import '../utils/app_errors.dart';
import '../constants/theme.dart';
import '../widgets/app_skeleton.dart';
import '../widgets/app_spinner.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/primary_button.dart';

enum JoinRoomStep { initial, searching, results }

class JoinRoomDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<JoinRoomDialog> createState() => _JoinRoomDialogState();
}

class _JoinRoomDialogState extends ConsumerState<JoinRoomDialog> {
  bool _isJoining = false;
  JoinRoomStep _step = JoinRoomStep.initial;

  @override
  void initState() {
    super.initState();
    // Refresh rooms when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(availableRoomsProvider);
    });
  }

  void _handleShareLocation() {
    setState(() => _step = JoinRoomStep.searching);

    Future.delayed(Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _step = JoinRoomStep.results);
      }
    });
  }

  Future<void> _joinRoom(Room room) async {
    if (_isJoining) return;

    setState(() => _isJoining = true);

    try {
      final dio = ref.read(dioProvider);
      final messenger = ScaffoldMessenger.maybeOf(context);
      await dio.post(
        '/rooms/${room.id}/join',
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      // Refresh joined rooms from backend
      ref.invalidate(joinedRoomsFutureProvider);
      // Refresh dashboard room list (source used by DashboardPage)
      ref.invalidate(roomsListProvider);

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop();
      messenger?.showSnackBar(
        SnackBar(content: Text('Successfully joined ${room.name}')),
      );
    } catch (e) {
      if (mounted) {
        String errorMessage;
        if (e is AppError) {
          errorMessage = e.getUserMessage();
        } else if (e is DioException) {
          // This shouldn't happen if services are using AppError, but handle it just in case
          errorMessage = "Couldn't join that room. Try again?";
        } else {
          errorMessage = "Something unexpected happened. Try again?";
        }

        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: BleyaTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Container(
      height: mediaQuery.size.height * 0.75,
      decoration: BoxDecoration(
        color: BleyaTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.all(BleyaTheme.contentPadding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Join a room',
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
            // Content
            Expanded(
              child: _buildStepContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case JoinRoomStep.initial:
        return _buildInitialStep();
      case JoinRoomStep.searching:
        return _buildSearchingStep();
      case JoinRoomStep.results:
        return _buildResultsStep();
    }
  }

  Widget _buildInitialStep() {
    return Padding(
      padding: EdgeInsets.all(BleyaTheme.contentPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: BleyaTheme.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.location,
              size: 56,
              color: BleyaTheme.primary,
            ),
          ),
          SizedBox(height: BleyaTheme.spacing2XL),
          Text(
            'Discovery mode',
            style: BleyaTheme.headingMedium.copyWith(fontSize: 28),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: BleyaTheme.spacingMD),
          Text(
            'Share your location to find active chat rooms in your current city.',
            style: BleyaTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: BleyaTheme.spacing3XL),
          PrimaryButton(
            text: 'Share location',
            onPressed: _handleShareLocation,
            trailingIcon: Icon(
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
          AppSpinner(radius: 20),
          SizedBox(height: BleyaTheme.spacing2XL),
          Text(
            'Scanning for nearby rooms...',
            style: BleyaTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRoomListSkeleton() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: BleyaTheme.contentPadding,
      ),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(bottom: BleyaTheme.spacingMD),
          child: Container(
            padding: EdgeInsets.all(BleyaTheme.spacingLG),
            decoration: BoxDecoration(
              color: BleyaTheme.glassSurface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(BleyaTheme.radiusMedium),
              border: Border.all(
                color: BleyaTheme.border,
                width: 1,
              ),
              boxShadow: BleyaTheme.glassShadow,
            ),
            child: const Row(
              children: [
                AppSkeleton.circle(size: 48),
                SizedBox(width: BleyaTheme.spacingLG),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSkeleton(
                        width: 160,
                        height: 16,
                      ),
                      SizedBox(height: BleyaTheme.spacingXS),
                      AppSkeleton(
                        width: 120,
                        height: 14,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: BleyaTheme.spacingSM),
                AppSkeleton(
                  width: 20,
                  height: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultsStep() {
    final roomsAsync = ref.watch(availableRoomsProvider);
    final joinedRoomsAsync = ref.watch(joinedRoomsFutureProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(BleyaTheme.contentPadding),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.location_solid,
                size: 20,
                color: BleyaTheme.primary,
              ),
              SizedBox(width: BleyaTheme.spacingSM),
              Text(
                'Nearby you',
                style: BleyaTheme.headingMedium.copyWith(fontSize: 20),
              ),
            ],
          ),
        ),
        Expanded(
          child: joinedRoomsAsync.when(
            data: (joinedRooms) => roomsAsync.when(
              data: (rooms) {
                if (rooms.isEmpty) {
                  return EmptyState(
                    icon: CupertinoIcons.chat_bubble,
                    title: 'No rooms available',
                    description: 'Check back later for new rooms',
                  );
                }

                // Filter out already joined rooms
                final availableRooms = rooms
                    .where((room) => !joinedRooms.any((jr) => jr.id == room.id))
                    .toList();

                if (availableRooms.isEmpty) {
                  final publicRoomCount =
                      joinedRooms.where((r) => r.type == 'public').length;
                  return EmptyState(
                    icon: CupertinoIcons.checkmark_circle,
                    title: 'You joined all available rooms',
                    description: publicRoomCount >= 5
                        ? 'You reached the limit of 5 group chats'
                        : 'Check back later for new rooms',
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: BleyaTheme.contentPadding,
                  ),
                  itemCount: availableRooms.length,
                  itemBuilder: (context, index) {
                    final room = availableRooms[index];
                    final isJoiningThis = _isJoining;

                    return Padding(
                      padding: EdgeInsets.only(bottom: BleyaTheme.spacingMD),
                      child: GestureDetector(
                        onTap: isJoiningThis ? null : () => _joinRoom(room),
                        child: Container(
                          padding: EdgeInsets.all(BleyaTheme.spacingLG),
                          decoration: BoxDecoration(
                            color:
                                BleyaTheme.glassSurface.withValues(alpha: 0.6),
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
                                imageUrl: null,
                                size: 48,
                                backgroundColor: BleyaTheme.primaryLight,
                                fallbackIcon: CupertinoIcons.person_2,
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
                                    ),
                                    SizedBox(height: BleyaTheme.spacingXS),
                                    Text(
                                      '128 active travelers',
                                      style: BleyaTheme.bodyMedium.copyWith(
                                        fontSize: 14,
                                        color: BleyaTheme.mutedForeground,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isJoiningThis)
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: AppSpinner(size: 20),
                                )
                              else
                                Icon(
                                  CupertinoIcons.chevron_right,
                                  size: 20,
                                  color: BleyaTheme.mutedForeground,
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
                  print('Error fetching rooms: $error');
                  print('Stack: $stack');
                }
                return Padding(
                  padding: EdgeInsets.all(BleyaTheme.contentPadding),
                  child: ErrorState(
                    title: 'Error loading rooms',
                    description: error.toString(),
                    onRetry: () {
                      ref.invalidate(availableRoomsProvider);
                    },
                  ),
                );
              },
            ),
            loading: _buildRoomListSkeleton,
            error: (error, stack) => Center(
              child: Text('Error loading joined rooms'),
            ),
          ),
        ),
      ],
    );
  }
}
