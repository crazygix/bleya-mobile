import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../use_cases/auth/request_code_use_case.dart';
import '../use_cases/auth/resend_code_use_case.dart';
import '../use_cases/auth/verify_code_use_case.dart';
import '../utils/app_errors.dart';

class AuthState {
  final bool isLoading;
  final String? errorMessage;

  AuthState({
    this.isLoading = false,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  final RequestCodeUseCase _requestCodeUseCase;
  final ResendCodeUseCase _resendCodeUseCase;
  final VerifyCodeUseCase _verifyCodeUseCase;

  AuthController(
    this._requestCodeUseCase,
    this._resendCodeUseCase,
    this._verifyCodeUseCase,
  ) : super(AuthState());

  Future<Map<String, dynamic>> requestCode(String phone) async {
    if (phone.isEmpty) {
      state = state.copyWith(errorMessage: "What's your number?");
      return {};
    }

    state = state.copyWith(
      errorMessage: null,
      isLoading: true,
    );

    try {
      final result = await _requestCodeUseCase(phone: phone);
      state = state.copyWith(
        isLoading: false,
        errorMessage: null,
      );
      return result;
    } catch (e) {
      final errorMessage = e is AppError ? e.getUserMessage() : "Something went wrong. Let's try that again.";
      state = state.copyWith(
        isLoading: false,
        errorMessage: errorMessage,
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>> resendCode(String phone) async {
    state = state.copyWith(
      errorMessage: null,
      isLoading: true,
    );

    try {
      final result = await _resendCodeUseCase(phone: phone);
      state = state.copyWith(
        isLoading: false,
        errorMessage: null,
      );
      return result;
    } catch (e) {
      final errorMessage = e is AppError ? e.getUserMessage() : "Something went wrong. Let's try that again.";
      state = state.copyWith(
        isLoading: false,
        errorMessage: errorMessage,
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verifyCode({
    required String phone,
    required String code,
  }) async {
    if (code.length != 6) {
      state = state.copyWith(
        errorMessage: "That code doesn't look complete. Try again?",
      );
      return {};
    }

    state = state.copyWith(
      errorMessage: null,
      isLoading: true,
    );

    try {
      final result = await _verifyCodeUseCase(phone: phone, code: code);
      state = state.copyWith(
        isLoading: false,
        errorMessage: null,
      );
      return result;
    } catch (e) {
      final errorMessage = e is AppError ? e.getUserMessage() : "Something went wrong. Let's try that again.";
      state = state.copyWith(
        isLoading: false,
        errorMessage: errorMessage,
      );
      rethrow;
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}
