import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/city.dart';
import '../use_cases/city/get_nearby_cities_use_case.dart';
import '../use_cases/city/join_city_use_case.dart';
import '../use_cases/location/get_current_location_use_case.dart';
import '../utils/app_errors.dart';

enum JoinRoomStep { initial, searching, results }

class JoinRoomState {
  static const Object _noValue = Object();

  final bool isJoining;
  final String? joiningCityId;
  final bool isSearchingNearby;
  final JoinRoomStep step;
  final String? searchError;
  final double? latitude;
  final double? longitude;
  final List<City> nearbyCities;

  final String searchQuery;
  final bool isLocationPermDeniedForever;

  const JoinRoomState({
    required this.isJoining,
    required this.joiningCityId,
    required this.isSearchingNearby,
    required this.step,
    required this.searchError,
    required this.latitude,
    required this.longitude,
    required this.nearbyCities,
    required this.searchQuery,
    required this.isLocationPermDeniedForever,
  });

  const JoinRoomState.initial()
      : isJoining = false,
        joiningCityId = null,
        isSearchingNearby = false,
        step = JoinRoomStep.initial,
        searchError = null,
        latitude = null,
        longitude = null,
        nearbyCities = const [],
        searchQuery = '',
        isLocationPermDeniedForever = false;

  JoinRoomState copyWith({
    bool? isJoining,
    Object? joiningCityId = _noValue,
    bool? isSearchingNearby,
    JoinRoomStep? step,
    Object? searchError = _noValue,
    Object? latitude = _noValue,
    Object? longitude = _noValue,
    List<City>? nearbyCities,
    String? searchQuery,
    bool? isLocationPermDeniedForever,
  }) {
    return JoinRoomState(
      isJoining: isJoining ?? this.isJoining,
      joiningCityId: identical(joiningCityId, _noValue)
          ? this.joiningCityId
          : joiningCityId as String?,
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
      nearbyCities: nearbyCities ?? this.nearbyCities,
      searchQuery: searchQuery ?? this.searchQuery,
      isLocationPermDeniedForever:
          isLocationPermDeniedForever ?? this.isLocationPermDeniedForever,
    );
  }
}

class JoinRoomController extends StateNotifier<JoinRoomState> {
  static const int nearbyLimit = 20;

  final GetNearbyCitiesUseCase _getNearbyCitiesUseCase;
  final JoinCityUseCase _joinCityUseCase;
  final GetCurrentLocationUseCase _getCurrentLocationUseCase;
  Timer? _searchDebounceTimer;

  JoinRoomController(
    this._getNearbyCitiesUseCase,
    this._joinCityUseCase,
    this._getCurrentLocationUseCase,
  ) : super(const JoinRoomState.initial());

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  void onSearchQueryChanged(String value) {
    if (!mounted) return;

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
      if (mounted) fetchNearbyCities();
    });
  }

  void clearSearchQuery() {
    if (!mounted) return;
    if (state.searchQuery.isEmpty) {
      return;
    }

    state = state.copyWith(searchQuery: '');
    _searchDebounceTimer?.cancel();

    if (state.step == JoinRoomStep.results &&
        state.latitude != null &&
        state.longitude != null) {
      fetchNearbyCities();
    }
  }

  Future<void> shareLocationAndSearch() async {
    if (state.isSearchingNearby) return;

    state = state.copyWith(
      step: JoinRoomStep.searching,
      searchError: null,
      isLocationPermDeniedForever: false,
    );

    await _resolveLocationAndSearch();
  }

  Future<void> _resolveLocationAndSearch() async {
    state = state.copyWith(isSearchingNearby: true);

    try {
      final position = await _getCurrentLocationUseCase();

      if (!mounted) return;

      state = state.copyWith(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      await fetchNearbyCities();
    } on AppLocationServiceDisabledException {
      _setSearchError('Turn on location to see what\'s nearby.');
    } on AppPermissionDeniedException {
      _setSearchError('Need location access to find your crowd.');
    } on AppPermissionDeniedForeverException {
      if (!mounted) return;
      state = state.copyWith(
        isLocationPermDeniedForever: true,
        searchError:
            'We need your location to find nearby chats. Check your settings?',
        nearbyCities: const [],
        step: JoinRoomStep.results,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Location discovery failed: $e');
      }
      if (mounted) {
        _setSearchError("That's strange, we couldn't find nearby chats.");
      }
    } finally {
      if (mounted) {
        state = state.copyWith(isSearchingNearby: false);
      }
    }
  }

  Future<void> fetchNearbyCities() async {
    final latitude = state.latitude;
    final longitude = state.longitude;
    if (latitude == null || longitude == null) {
      _setSearchError(
        'Not ready yet. Tap "Find city chats" again.',
      );
      return;
    }

    state = state.copyWith(
      isSearchingNearby: true,
      searchError: null,
    );

    try {
      final cities = await _getNearbyCitiesUseCase(
        latitude: latitude,
        longitude: longitude,
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      state = state.copyWith(
        nearbyCities: cities,
        step: JoinRoomStep.results,
      );
    } on TimeoutException {
      if (mounted) {
        _setSearchError('Taking a while. Want to retry?');
      }
    } catch (e) {
      if (!mounted) return;
      if (e is AppError) {
        _setSearchError(e.getUserMessage());
      } else {
        _setSearchError("Something went sideways. Try again?");
      }
    } finally {
      if (mounted) {
        state = state.copyWith(isSearchingNearby: false);
      }
    }
  }

  Future<void> joinCity(City city) async {
    if (state.isJoining) return;

    state = state.copyWith(
      isJoining: true,
      joiningCityId: city.id,
    );

    try {
      await _joinCityUseCase(city.id);
    } finally {
      if (mounted) {
        state = state.copyWith(
          isJoining: false,
          joiningCityId: null,
        );
      }
    }
  }

  void _setSearchError(String message) {
    if (!mounted) return;
    state = state.copyWith(
      searchError: message,
      nearbyCities: const [],
      step: JoinRoomStep.results,
    );
  }

  Future<void> openLocationSettings() async {
    await _getCurrentLocationUseCase.openAppSettings();
  }
}
