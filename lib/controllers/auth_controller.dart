import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/auth_result.dart';
import '../use_cases/auth/request_code_use_case.dart';
import '../use_cases/auth/resend_code_use_case.dart';
import '../use_cases/auth/verify_code_use_case.dart';

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

  String _resolveErrorMessage(Object error) {
    final rawMessage = error.toString();
    final message = rawMessage.startsWith('Exception: ')
        ? rawMessage.substring('Exception: '.length)
        : rawMessage;
    if (message.isNotEmpty && message != 'Exception') {
      return message;
    }
    return "Something went wrong. Let's try that again.";
  }

  Future<CodeRequestResult?> requestCode(String phone) async {
    if (phone.isEmpty) {
      state = state.copyWith(errorMessage: "What's your number?");
      return null;
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
      state = state.copyWith(
        isLoading: false,
        errorMessage: _resolveErrorMessage(e),
      );
      rethrow;
    }
  }

  Future<CodeRequestResult> resendCode(String phone) async {
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
      state = state.copyWith(
        isLoading: false,
        errorMessage: _resolveErrorMessage(e),
      );
      rethrow;
    }
  }

  Future<VerifyCodeResult?> verifyCode({
    required String phone,
    required String code,
  }) async {
    if (code.length != 6) {
      state = state.copyWith(
        errorMessage: "That code doesn't look complete. Try again?",
      );
      return null;
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
      state = state.copyWith(
        isLoading: false,
        errorMessage: _resolveErrorMessage(e),
      );
      rethrow;
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}
