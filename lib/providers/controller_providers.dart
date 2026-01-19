import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/username_controller.dart';
import '../controllers/auth_controller.dart';
import 'use_case_providers.dart';

final usernameControllerProvider =
    StateNotifierProvider<UsernameController, UsernameState>((ref) {
  final checkUsername = ref.watch(checkUsernameUseCaseProvider);
  final setUsername = ref.watch(setUsernameUseCaseProvider);
  final uploadImage = ref.watch(uploadProfileImageUseCaseProvider);
  return UsernameController(checkUsername, setUsername, uploadImage);
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final requestCode = ref.watch(requestCodeUseCaseProvider);
  final resendCode = ref.watch(resendCodeUseCaseProvider);
  final verifyCode = ref.watch(verifyCodeUseCaseProvider);
  return AuthController(requestCode, resendCode, verifyCode);
});
