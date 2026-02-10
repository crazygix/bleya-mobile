import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../use_cases/auth/check_username_use_case.dart';
import '../use_cases/auth/set_username_use_case.dart';
import '../use_cases/user/upload_profile_image_use_case.dart';
import '../utils/app_errors.dart';

class UsernameState {
  final bool isValid;
  final bool isChecking;
  final bool hasCheckedAvailability;
  final String? errorMessage;
  final File? selectedImage;
  final bool isLoading;

  UsernameState({
    this.isValid = false,
    this.isChecking = false,
    this.hasCheckedAvailability = false,
    this.errorMessage,
    this.selectedImage,
    this.isLoading = false,
  });

  UsernameState copyWith({
    bool? isValid,
    bool? isChecking,
    bool? hasCheckedAvailability,
    String? errorMessage,
    File? selectedImage,
    bool? isLoading,
  }) {
    return UsernameState(
      isValid: isValid ?? this.isValid,
      isChecking: isChecking ?? this.isChecking,
      hasCheckedAvailability:
          hasCheckedAvailability ?? this.hasCheckedAvailability,
      errorMessage: errorMessage,
      selectedImage: selectedImage ?? this.selectedImage,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class UsernameController extends StateNotifier<UsernameState> {
  final CheckUsernameUseCase _checkUsernameUseCase;
  final SetUsernameUseCase _setUsernameUseCase;
  final UploadProfileImageUseCase _uploadProfileImageUseCase;
  Timer? _debounceTimer;

  UsernameController(
    this._checkUsernameUseCase,
    this._setUsernameUseCase,
    this._uploadProfileImageUseCase,
  ) : super(UsernameState());

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void validateUsername(String username) {
    final trimmed = username.trim().toLowerCase();

    _debounceTimer?.cancel();

    if (trimmed.length < 3) {
      state = state.copyWith(
        isValid: false,
        isChecking: false,
        hasCheckedAvailability: false,
      );
      return;
    }

    if (!RegExp(r'^[a-z0-9_]{3,30}$').hasMatch(trimmed)) {
      state = state.copyWith(
        isValid: false,
        isChecking: false,
        hasCheckedAvailability: false,
      );
      return;
    }

    state = state.copyWith(isChecking: true);

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final currentUsername = trimmed;

      if (!RegExp(r'^[a-z0-9_]{3,30}$').hasMatch(currentUsername)) {
        state = state.copyWith(
          isValid: false,
          isChecking: false,
        );
        return;
      }

      try {
        final isAvailable =
            await _checkUsernameUseCase(username: currentUsername);
        state = state.copyWith(
          isValid: isAvailable,
          isChecking: false,
          hasCheckedAvailability: true,
        );
      } catch (e) {
        state = state.copyWith(
          isValid: false,
          isChecking: false,
          hasCheckedAvailability: true,
        );
      }
    });
  }

  void setSelectedImage(File? image) {
    state = state.copyWith(selectedImage: image);
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  void setError(String errorMessage) {
    state = state.copyWith(errorMessage: errorMessage);
  }

  void resetAvailabilityCheck() {
    state = state.copyWith(hasCheckedAvailability: false);
  }

  Future<void> setUsername(String username) async {
    final trimmed = username.trim().toLowerCase();

    if (trimmed.isEmpty) {
      state = state.copyWith(errorMessage: "How should we call you?");
      return;
    }

    if (!RegExp(r'^[a-z0-9_]{3,30}$').hasMatch(trimmed)) {
      state = state.copyWith(
        errorMessage:
            "Keep it simple: 3-30 characters, just letters, numbers, and underscores.",
      );
      return;
    }

    state = state.copyWith(
      errorMessage: null,
      isLoading: true,
    );

    try {
      if (state.selectedImage != null) {
        await _uploadProfileImageUseCase(state.selectedImage!);
      }

      await _setUsernameUseCase(username: trimmed);
    } catch (e) {
      final errorMessage = e is AppError
          ? e.getUserMessage()
          : "Something went wrong. Let's try that again.";
      state = state.copyWith(
        errorMessage: errorMessage,
        isLoading: false,
      );
      rethrow;
    } finally {
      if (!state.isLoading) {
        state = state.copyWith(isLoading: false);
      }
    }
  }
}
