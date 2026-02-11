import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/theme.dart';
import '../providers/auth_providers.dart';
import '../providers/chat_providers.dart';
import '../providers/use_case_providers.dart';
import '../utils/app_errors.dart';
import '../widgets/app_skeleton.dart';
import '../widgets/app_spinner.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/primary_button.dart';
import '../widgets/profile_avatar.dart';

enum JoinRoomStep { initial, searching, results }

class JoinRoomDialog extends ConsumerStatefulWidget {
  const JoinRoomDialog({super.key});

  @override
  ConsumerState<JoinRoomDialog> createState() => _JoinRoomDialogState();
}

class _JoinRoomDialogState extends ConsumerState<JoinRoomDialog> {
  static const int _nearbyLimit = 30;
  static const double _fixedRadiusKm = 30;

  bool _isJoining = false;
  String? _joiningRoomId;
  bool _isSearchingNearby = false;
  JoinRoomStep _step = JoinRoomStep.initial;

  String? _searchError;
  double? _latitude;
  double? _longitude;
  List<Room> _nearbyRooms = const [];

  Future<void> _handleShareLocation() async {
    if (_isSearchingNearby) return;

    setState(() {
      _step = JoinRoomStep.searching;
      _searchError = null;
    });

    await _resolveLocationAndSearch();
  }

  Future<void> _resolveLocationAndSearch() async {
    setState(() => _isSearchingNearby = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setSearchError(
          'Location services are turned off. Enable GPS and try again.',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _setSearchError(
          'Location permission is required to discover nearby city rooms.',
        );
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _setSearchError(
          'Location permission is permanently denied. Enable it in system settings.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      if (!mounted) return;

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _step = JoinRoomStep.results;
      });

      await _fetchNearbyRooms();
    } catch (e) {
      if (kDebugMode) {
        print('Location discovery failed: $e');
      }
      _setSearchError("Couldn't read your location. Try again?");
    } finally {
      if (mounted) {
        setState(() => _isSearchingNearby = false);
      }
    }
  }

  Future<void> _fetchNearbyRooms() async {
    final latitude = _latitude;
    final longitude = _longitude;
    if (latitude == null || longitude == null) {
      _setSearchError('Your location is missing. Share location again.');
      return;
    }

    setState(() {
      _isSearchingNearby = true;
      _searchError = null;
    });

    try {
      final useCase = ref.read(getNearbyRoomsUseCaseProvider);
      final rooms = await useCase(
        latitude: latitude,
        longitude: longitude,
        radiusKm: _fixedRadiusKm,
        limit: _nearbyLimit,
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      setState(() {
        _nearbyRooms = rooms;
        _step = JoinRoomStep.results;
      });
    } on TimeoutException {
      _setSearchError('Nearby search timed out. Try again?');
    } catch (e) {
      if (e is AppError) {
        _setSearchError(e.getUserMessage());
      } else {
        _setSearchError("Couldn't load nearby cities. Try again?");
      }
    } finally {
      if (mounted) {
        setState(() => _isSearchingNearby = false);
      }
    }
  }

  void _setSearchError(String message) {
    if (!mounted) return;

    setState(() {
      _searchError = message;
      _nearbyRooms = [];
      _step = JoinRoomStep.results;
    });
  }

  Future<void> _joinRoom(Room room) async {
    if (_isJoining) return;

    setState(() {
      _isJoining = true;
      _joiningRoomId = room.id;
    });

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

      ref.invalidate(joinedRoomsFutureProvider);
      ref.invalidate(roomsListProvider);

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop();
      messenger?.showSnackBar(
        SnackBar(content: Text('Successfully joined ${room.name}')),
      );
    } catch (e) {
      if (!mounted) return;

      String errorMessage;
      if (e is AppError) {
        errorMessage = e.getUserMessage();
      } else if (e is DioException) {
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
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
          _joiningRoomId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

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
            Expanded(child: _buildStepContent()),
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
            'Searching within ${_fixedRadiusKm.toStringAsFixed(0)} km.',
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

  Widget _buildResultsStep() {
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
                      'Showing cities within ${_fixedRadiusKm.toStringAsFixed(0)} km',
                      style: BleyaTheme.bodyMedium.copyWith(
                        color: BleyaTheme.mutedForeground,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(24, 24),
                    onPressed: _isSearchingNearby ? null : _fetchNearbyRooms,
                    child: Icon(
                      CupertinoIcons.arrow_clockwise,
                      size: 18,
                      color: BleyaTheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_isSearchingNearby)
          const LinearProgressIndicator(minHeight: 2)
        else
          const SizedBox(height: 2),
        Expanded(
          child: joinedRoomsAsync.when(
            data: (joinedRooms) {
              final availableRooms = _nearbyRooms.where((room) {
                final joinedByList = joinedRooms.any((jr) => jr.id == room.id);
                return !room.isJoined && !joinedByList;
              }).toList()
                ..sort((a, b) {
                  final aDistance = a.distanceKm ?? 9999;
                  final bDistance = b.distanceKm ?? 9999;
                  return aDistance.compareTo(bDistance);
                });

              if (_searchError != null) {
                return Padding(
                  padding: EdgeInsets.all(BleyaTheme.contentPadding),
                  child: ErrorState(
                    title: 'Couldn\'t load nearby rooms',
                    description: _searchError!,
                    onRetry: _latitude != null && _longitude != null
                        ? _fetchNearbyRooms
                        : _handleShareLocation,
                  ),
                );
              }

              if (_nearbyRooms.isEmpty) {
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
                  final isJoiningThis = _isJoining && _joiningRoomId == room.id;
                  final distanceLabel = room.distanceKm != null
                      ? '${room.distanceKm!.toStringAsFixed(1)} km away'
                      : 'Nearby';

                  return Padding(
                    padding: EdgeInsets.only(bottom: BleyaTheme.spacingMD),
                    child: GestureDetector(
                      onTap: _isJoining ? null : () => _joinRoom(room),
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
}
