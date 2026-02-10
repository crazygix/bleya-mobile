import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/user_profile.dart';
import 'auth_providers.dart';
import 'use_case_providers.dart';

class ProfileController extends StateNotifier<AsyncValue<UserProfile?>> {
  ProfileController(this.ref, {required String? token})
      : super(token == null || token.isEmpty
            ? const AsyncValue.data(null)
            : const AsyncValue.loading()) {
    if (token != null && token.isNotEmpty) {
      Future.microtask(() async {
        try {
          await fetchProfile();
        } catch (_) {
          // Keep failure in provider state; avoid uncaught async errors.
        }
      });
    }
  }

  final Ref ref;
  Future<UserProfile>? _inFlightRequest;

  Future<UserProfile> fetchProfile({bool forceRefresh = false}) async {
    final cachedProfile = state.asData?.value;
    if (!forceRefresh && cachedProfile != null) {
      return cachedProfile;
    }

    final existingRequest = _inFlightRequest;
    if (existingRequest != null) {
      return existingRequest;
    }

    if (cachedProfile == null) {
      state = const AsyncValue.loading();
    }

    final request = _fetchFromNetwork(cachedProfile);
    _inFlightRequest = request;

    try {
      return await request;
    } finally {
      if (identical(_inFlightRequest, request)) {
        _inFlightRequest = null;
      }
    }
  }

  Future<UserProfile> _fetchFromNetwork(UserProfile? cachedProfile) async {
    try {
      final getProfileUseCase = ref.read(getProfileUseCaseProvider);
      final profile = await getProfileUseCase();
      state = AsyncValue.data(profile);
      return profile;
    } catch (error, stackTrace) {
      if (cachedProfile != null) {
        state = AsyncValue.data(cachedProfile);
      } else {
        state = AsyncValue.error(error, stackTrace);
      }
      rethrow;
    }
  }

  void setProfile(UserProfile profile) {
    state = AsyncValue.data(profile);
  }
}

final profileProvider =
    StateNotifierProvider<ProfileController, AsyncValue<UserProfile?>>((ref) {
  final token = ref.watch(tokenProvider);
  return ProfileController(ref, token: token);
});
