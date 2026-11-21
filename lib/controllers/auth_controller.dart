import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/analytics_event.dart';
import '../domain/entities/auth_result.dart';
import '../use_cases/analytics/record_analytics_event_use_case.dart';
import '../use_cases/auth/register_passkey_use_case.dart';
import '../use_cases/auth/sign_in_as_test_user_use_case.dart';
import '../use_cases/auth/sign_in_with_apple_use_case.dart';
import '../use_cases/auth/sign_in_with_google_use_case.dart';
import '../use_cases/auth/sign_in_with_passkey_use_case.dart';
import '../utils/auth_error_messages.dart';
import '../utils/sign_in_analytics.dart';

enum AuthAction {
  signInWithGoogle,
  signInWithApple,
  signInWithPasskey,
  signInAsTestUser,
  registerPasskey,
}

enum AuthNavigationTarget {
  username,
  passkeyPrompt,
  home,
}

class AuthNavigationRequest {
  final AuthNavigationTarget target;
  final bool showPasskeyPromptAfterCompletion;

  const AuthNavigationRequest({
    required this.target,
    this.showPasskeyPromptAfterCompletion = false,
  });
}

class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final AuthAction? activeAction;
  final AuthNavigationRequest? navigationRequest;

  AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.activeAction,
    this.navigationRequest,
  });

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    AuthAction? activeAction,
    AuthNavigationRequest? navigationRequest,
    bool clearError = false,
    bool clearAction = false,
    bool clearNavigation = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      activeAction: clearAction ? null : activeAction ?? this.activeAction,
      navigationRequest:
          clearNavigation ? null : navigationRequest ?? this.navigationRequest,
    );
  }
}

/// Whether this build offers "Sign in as test user". A compile-time constant,
/// so prod builds (FLUTTER_ENV=prod) leave the button and its code out.
const bool devTestSignInAvailable =
    String.fromEnvironment('FLUTTER_ENV') == 'dev';

typedef StoreAuthToken = void Function(String token);
typedef LoadPasskeyAvailability = Future<bool> Function();

class AuthController extends StateNotifier<AuthState> {
  final SignInWithGoogleUseCase _signInWithGoogleUseCase;
  final SignInWithAppleUseCase _signInWithAppleUseCase;
  final SignInWithPasskeyUseCase _signInWithPasskeyUseCase;
  final RegisterPasskeyUseCase _registerPasskeyUseCase;
  final RecordAnalyticsEventUseCase _recordAnalyticsEvent;
  final StoreAuthToken _storeAuthToken;
  final LoadPasskeyAvailability _loadPasskeyAvailability;
  final SignInAsTestUserUseCase? _signInAsTestUserUseCase;

  AuthController(
    this._signInWithGoogleUseCase,
    this._signInWithAppleUseCase,
    this._signInWithPasskeyUseCase,
    this._registerPasskeyUseCase,
    this._recordAnalyticsEvent,
    this._storeAuthToken,
    this._loadPasskeyAvailability, {
    SignInAsTestUserUseCase? signInAsTestUserUseCase,
  })  : _signInAsTestUserUseCase = signInAsTestUserUseCase,
        super(AuthState());

  AuthNavigationRequest _buildUsernameNavigation(AuthSessionResult result) {
    return AuthNavigationRequest(
      target: AuthNavigationTarget.username,
      showPasskeyPromptAfterCompletion: !result.hasPasskey,
    );
  }

  Future<AuthNavigationRequest> _resolvePostSignInNavigation(
    AuthSessionResult result,
  ) async {
    if (result.requiresUsername) {
      return _buildUsernameNavigation(result);
    }

    if (!result.hasPasskey) {
      final canOfferPasskey = await _loadPasskeyAvailability().catchError(
        (_) => false,
      );
      if (canOfferPasskey) {
        return const AuthNavigationRequest(
          target: AuthNavigationTarget.passkeyPrompt,
        );
      }
    }

    return const AuthNavigationRequest(
      target: AuthNavigationTarget.home,
    );
  }

  /// What to show when [action] fails with [error]: nothing for a cancel,
  /// never the error's own text. Debug builds also log the error.
  String _errorMessageFor(AuthAction action, Object error) {
    if (kDebugMode) {
      print('auth/${action.name} failed: $error');
    }
    final fallback = switch (action) {
      AuthAction.signInWithGoogle => "Google sign-in didn't finish. Try again?",
      AuthAction.signInWithApple => "Apple sign-in didn't finish. Try again?",
      AuthAction.signInWithPasskey =>
        "Passkey sign-in didn't finish. Try again?",
      AuthAction.signInAsTestUser =>
        "Test sign-in failed. Is the local backend running with DEV_LOGIN_ENABLED=true?",
      AuthAction.registerPasskey => "Couldn't add a passkey. Try again?",
    };
    return authErrorMessage(error, fallback: fallback);
  }

  /// Signs in with [method] through [callback]. Analytics hear about the
  /// attempt, and about a failure the backend never saw (the backend records
  /// the rest, and every success).
  Future<AuthSessionResult?> _runSessionAction(
    AuthAction action,
    SignInMethod? method,
    Future<AuthSessionResult> Function() callback,
  ) async {
    state = state.copyWith(
      isLoading: true,
      activeAction: action,
      clearError: true,
      clearNavigation: true,
    );
    if (method != null) _recordAnalyticsEvent(SignInStarted(method));

    try {
      final result = await callback();
      _storeAuthToken(result.token);
      final navigationRequest = await _resolvePostSignInNavigation(result);
      state = state.copyWith(
        isLoading: false,
        clearError: true,
        clearAction: true,
        navigationRequest: navigationRequest,
      );
      return result;
    } catch (e) {
      final failure = method == null ? null : signInFailureEvent(method, e);
      if (failure != null) {
        _recordAnalyticsEvent(failure);
      }
      final errorMessage = _errorMessageFor(action, e);
      state = state.copyWith(
        isLoading: false,
        errorMessage: errorMessage.isEmpty ? null : errorMessage,
        clearAction: true,
      );
      return null;
    }
  }

  Future<T?> _runAction<T>(
    AuthAction action,
    Future<T> Function() callback,
  ) async {
    state = state.copyWith(
      isLoading: true,
      activeAction: action,
      clearError: true,
    );

    try {
      final result = await callback();
      state = state.copyWith(
        isLoading: false,
        clearError: true,
        clearAction: true,
      );
      return result;
    } catch (e) {
      final errorMessage = _errorMessageFor(action, e);
      state = state.copyWith(
        isLoading: false,
        errorMessage: errorMessage.isEmpty ? null : errorMessage,
        clearAction: true,
      );
      return null;
    }
  }

  Future<AuthSessionResult?> signInWithGoogle() {
    return _runSessionAction(
      AuthAction.signInWithGoogle,
      SignInMethod.google,
      () => _signInWithGoogleUseCase(),
    );
  }

  Future<AuthSessionResult?> signInWithApple() {
    return _runSessionAction(
      AuthAction.signInWithApple,
      SignInMethod.apple,
      () => _signInWithAppleUseCase(),
    );
  }

  Future<AuthSessionResult?> signInWithPasskey() {
    return _runSessionAction(
      AuthAction.signInWithPasskey,
      SignInMethod.passkey,
      () => _signInWithPasskeyUseCase(),
    );
  }

  /// Dev builds only (see [devTestSignInAvailable]): signs in as [username]
  /// through the local backend's dev login. Not counted in analytics.
  Future<AuthSessionResult?> signInAsTestUser(String username) {
    final useCase = _signInAsTestUserUseCase;
    if (useCase == null) return Future.value(null);
    return _runSessionAction(
      AuthAction.signInAsTestUser,
      null,
      () => useCase(username: username),
    );
  }

  Future<AuthSecurityStatus?> registerPasskey() {
    return _runAction(
      AuthAction.registerPasskey,
      () => _registerPasskeyUseCase(),
    );
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void consumeNavigation() {
    state = state.copyWith(clearNavigation: true);
  }
}
