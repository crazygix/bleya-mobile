import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/username_controller.dart';
import '../controllers/auth_controller.dart';
import '../controllers/join_room_controller.dart';
import 'auth_providers.dart';
import 'use_case_providers.dart';

final usernameControllerProvider =
    StateNotifierProvider<UsernameController, UsernameState>((ref) {
  final checkUsername = ref.watch(checkUsernameUseCaseProvider);
  final setUsername = ref.watch(setUsernameUseCaseProvider);
  final uploadImage = ref.watch(uploadProfileImageUseCaseProvider);
  final passkeyAuthService = ref.watch(passkeyAuthServiceProvider);
  return UsernameController(
    checkUsername,
    setUsername,
    uploadImage,
    () => passkeyAuthService.isAvailable(),
  );
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final signInWithGoogle = ref.watch(signInWithGoogleUseCaseProvider);
  final signInWithApple = ref.watch(signInWithAppleUseCaseProvider);
  final signInWithPasskey = ref.watch(signInWithPasskeyUseCaseProvider);
  final linkAuthProvider = ref.watch(linkAuthProviderUseCaseProvider);
  final registerPasskey = ref.watch(registerPasskeyUseCaseProvider);
  final passkeyAuthService = ref.watch(passkeyAuthServiceProvider);
  return AuthController(
    signInWithGoogle,
    signInWithApple,
    signInWithPasskey,
    linkAuthProvider,
    registerPasskey,
    (token) => ref.read(tokenProvider.notifier).state = token,
    () => passkeyAuthService.isAvailable(),
  );
});

final joinRoomControllerProvider =
    StateNotifierProvider.autoDispose<JoinRoomController, JoinRoomState>((ref) {
  final getNearbyCities = ref.watch(getNearbyCitiesUseCaseProvider);
  final joinCity = ref.watch(joinCityUseCaseProvider);
  final getCurrentLocation = ref.watch(getCurrentLocationUseCaseProvider);
  return JoinRoomController(getNearbyCities, joinCity, getCurrentLocation);
});
