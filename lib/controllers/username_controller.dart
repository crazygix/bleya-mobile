import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../use_cases/auth/check_username_use_case.dart';
import '../use_cases/auth/set_username_use_case.dart';
import '../use_cases/user/upload_profile_image_use_case.dart';
import '../utils/app_errors.dart';
import '../domain/entities/user_profile.dart';

class UsernameState {
  final bool isValid;
  final bool isChecking;
  final bool hasCheckedAvailability;
  final String? errorMessage;
  final File? selectedImage;
  final bool isLoading;
  final UserProfile? completedProfile;
  final UsernameCompletionRequest? completionRequest;

  UsernameState({
    this.isValid = false,
    this.isChecking = false,
    this.hasCheckedAvailability = false,
    this.errorMessage,
    this.selectedImage,
    this.isLoading = false,
    this.completedProfile,
    this.completionRequest,
  });

  UsernameState copyWith({
    bool? isValid,
    bool? isChecking,
    bool? hasCheckedAvailability,
    String? errorMessage,
    File? selectedImage,
    bool? isLoading,
    UserProfile? completedProfile,
    UsernameCompletionRequest? completionRequest,
    bool clearCompletion = false,
  }) {
    return UsernameState(
      isValid: isValid ?? this.isValid,
      isChecking: isChecking ?? this.isChecking,
      hasCheckedAvailability:
          hasCheckedAvailability ?? this.hasCheckedAvailability,
      errorMessage: errorMessage,
      selectedImage: selectedImage ?? this.selectedImage,
      isLoading: isLoading ?? this.isLoading,
      completedProfile:
          clearCompletion ? null : completedProfile ?? this.completedProfile,
      completionRequest: clearCompletion
          ? null
          : completionRequest ?? this.completionRequest,
    );
  }
}

enum UsernameCompletionTarget {
  passkeyPrompt,
  home,
}

class UsernameCompletionRequest {
  final UsernameCompletionTarget target;

  const UsernameCompletionRequest({
    required this.target,
  });
}

typedef LoadPasskeyAvailability = Future<bool> Function();

class UsernameController extends StateNotifier<UsernameState> {
  final CheckUsernameUseCase _checkUsernameUseCase;
  final SetUsernameUseCase _setUsernameUseCase;
  final UploadProfileImageUseCase _uploadProfileImageUseCase;
  final LoadPasskeyAvailability _loadPasskeyAvailability;
  Timer? _debounceTimer;

  UsernameController(
    this._checkUsernameUseCase,
    this._setUsernameUseCase,
    this._uploadProfileImageUseCase,
    this._loadPasskeyAvailability,
  ) : super(UsernameState());

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void resetTransientUiState() {
    _debounceTimer?.cancel();
    state = state.copyWith(
      isValid: false,
      isChecking: false,
      hasCheckedAvailability: false,
      errorMessage: null,
      isLoading: false,
      clearCompletion: true,
    );
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

  Future<UserProfile> submitUsername(
    String username, {
    required bool showPasskeyPromptAfterCompletion,
  }) async {
    if (state.isLoading) {
      throw StateError('Username submission already in progress');
    }

    final trimmed = username.trim().toLowerCase();

    if (trimmed.isEmpty) {
      state = state.copyWith(errorMessage: "How should we call you?");
      throw StateError('Username is empty');
    }

    if (!RegExp(r'^[a-z0-9_]{3,30}$').hasMatch(trimmed)) {
      state = state.copyWith(
        errorMessage:
            "Keep it simple: 3-30 characters, just letters, numbers, and underscores.",
      );
      throw StateError('Username format is invalid');
    }

    state = state.copyWith(
      errorMessage: null,
      isLoading: true,
    );

    try {
      if (state.selectedImage != null) {
        await _uploadProfileImageUseCase(state.selectedImage!);
      }

      final profile = await _setUsernameUseCase(username: trimmed);
      final canOfferPasskey = showPasskeyPromptAfterCompletion
          ? await _loadPasskeyAvailability().catchError((_) => false)
          : false;

      state = state.copyWith(
        completedProfile: profile,
        completionRequest: UsernameCompletionRequest(
          target: canOfferPasskey
              ? UsernameCompletionTarget.passkeyPrompt
              : UsernameCompletionTarget.home,
        ),
      );
      return profile;
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
      if (state.isLoading) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  void consumeCompletion() {
    state = state.copyWith(clearCompletion: true);
  }
}
