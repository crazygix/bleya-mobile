import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../domain/entities/room.dart';
import '../use_cases/room/get_nearby_rooms_use_case.dart';
import '../use_cases/room/join_room_use_case.dart';
import '../utils/app_errors.dart';

enum JoinRoomStep { initial, searching, results }

class JoinRoomState {
  static const Object _noValue = Object();

  final bool isJoining;
  final String? joiningRoomId;
  final bool isSearchingNearby;
  final JoinRoomStep step;
  final String? searchError;
  final double? latitude;
  final double? longitude;
  final List<Room> nearbyRooms;
  final String searchQuery;

  const JoinRoomState({
    required this.isJoining,
    required this.joiningRoomId,
    required this.isSearchingNearby,
    required this.step,
    required this.searchError,
    required this.latitude,
    required this.longitude,
    required this.nearbyRooms,
    required this.searchQuery,
  });

  const JoinRoomState.initial()
      : isJoining = false,
        joiningRoomId = null,
        isSearchingNearby = false,
        step = JoinRoomStep.initial,
        searchError = null,
        latitude = null,
        longitude = null,
        nearbyRooms = const [],
        searchQuery = '';

  JoinRoomState copyWith({
    bool? isJoining,
    Object? joiningRoomId = _noValue,
    bool? isSearchingNearby,
    JoinRoomStep? step,
    Object? searchError = _noValue,
    Object? latitude = _noValue,
    Object? longitude = _noValue,
    List<Room>? nearbyRooms,
    String? searchQuery,
  }) {
    return JoinRoomState(
      isJoining: isJoining ?? this.isJoining,
      joiningRoomId: identical(joiningRoomId, _noValue)
          ? this.joiningRoomId
          : joiningRoomId as String?,
      isSearchingNearby: isSearchingNearby ?? this.isSearchingNearby,
      step: step ?? this.step,
      searchError: identical(searchError, _noValue)
          ? this.searchError
          : searchError as String?,
      latitude:
          identical(latitude, _noValue) ? this.latitude : latitude as double?,
      longitude: identical(longitude, _noValue)
          ? this.longitude
          : longitude as double?,
      nearbyRooms: nearbyRooms ?? this.nearbyRooms,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class JoinRoomController extends StateNotifier<JoinRoomState> {
  static const int nearbyLimit = 30;
  static const double fixedRadiusKm = 30;

  final GetNearbyRoomsUseCase _getNearbyRoomsUseCase;
  final JoinRoomUseCase _joinRoomUseCase;
  Timer? _searchDebounceTimer;

  JoinRoomController(this._getNearbyRoomsUseCase, this._joinRoomUseCase)
      : super(const JoinRoomState.initial());

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  void onSearchQueryChanged(String value) {
    final normalized = value.trim();
    if (normalized == state.searchQuery) {
      return;
    }

    state = state.copyWith(searchQuery: normalized);
    _searchDebounceTimer?.cancel();

    if (state.step != JoinRoomStep.results ||
        state.latitude == null ||
        state.longitude == null) {
      return;
    }

    _searchDebounceTimer = Timer(const Duration(milliseconds: 280), () {
      fetchNearbyRooms();
    });
  }

  void clearSearchQuery() {
    if (state.searchQuery.isEmpty) {
      return;
    }

    state = state.copyWith(searchQuery: '');
    _searchDebounceTimer?.cancel();

    if (state.step == JoinRoomStep.results &&
        state.latitude != null &&
        state.longitude != null) {
      fetchNearbyRooms();
    }
  }

  Future<void> shareLocationAndSearch() async {
    if (state.isSearchingNearby) return;

    state = state.copyWith(
      step: JoinRoomStep.searching,
      searchError: null,
    );

    await _resolveLocationAndSearch();
  }

  Future<void> _resolveLocationAndSearch() async {
    state = state.copyWith(isSearchingNearby: true);

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

      state = state.copyWith(
        latitude: position.latitude,
        longitude: position.longitude,
        step: JoinRoomStep.results,
      );

      await fetchNearbyRooms();
    } catch (e) {
      if (kDebugMode) {
        print('Location discovery failed: $e');
      }
      _setSearchError("Couldn't read your location. Try again?");
    } finally {
      state = state.copyWith(isSearchingNearby: false);
    }
  }

  Future<void> fetchNearbyRooms() async {
    final latitude = state.latitude;
    final longitude = state.longitude;
    if (latitude == null || longitude == null) {
      _setSearchError('Your location is missing. Share location again.');
      return;
    }

    state = state.copyWith(
      isSearchingNearby: true,
      searchError: null,
    );

    try {
      final rooms = await _getNearbyRoomsUseCase(
        latitude: latitude,
        longitude: longitude,
        radiusKm: fixedRadiusKm,
        limit: nearbyLimit,
        searchQuery: state.searchQuery.isEmpty ? null : state.searchQuery,
      ).timeout(const Duration(seconds: 15));

      state = state.copyWith(
        nearbyRooms: rooms,
        step: JoinRoomStep.results,
      );
    } on TimeoutException {
      _setSearchError('Nearby search timed out. Try again?');
    } catch (e) {
      if (e is AppError) {
        _setSearchError(e.getUserMessage());
      } else {
        _setSearchError("Couldn't load nearby cities. Try again?");
      }
    } finally {
      state = state.copyWith(isSearchingNearby: false);
    }
  }

  Future<void> joinRoom(Room room) async {
    if (state.isJoining) return;

    state = state.copyWith(
      isJoining: true,
      joiningRoomId: room.id,
    );

    try {
      await _joinRoomUseCase(room.id);
    } finally {
      state = state.copyWith(
        isJoining: false,
        joiningRoomId: null,
      );
    }
  }

  void _setSearchError(String message) {
    state = state.copyWith(
      searchError: message,
      nearbyRooms: const [],
      step: JoinRoomStep.results,
    );
  }
}
