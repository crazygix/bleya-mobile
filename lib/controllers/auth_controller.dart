import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:passkeys/exceptions.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../domain/entities/auth_result.dart';
import '../use_cases/auth/register_passkey_use_case.dart';
import '../use_cases/auth/sign_in_with_apple_use_case.dart';
import '../use_cases/auth/sign_in_with_google_use_case.dart';
import '../use_cases/auth/sign_in_with_passkey_use_case.dart';

enum AuthAction {
  signInWithGoogle,
  signInWithApple,
  signInWithPasskey,
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

typedef StoreAuthToken = void Function(String token);
typedef LoadPasskeyAvailability = Future<bool> Function();

class AuthController extends StateNotifier<AuthState> {
  final SignInWithGoogleUseCase _signInWithGoogleUseCase;
  final SignInWithAppleUseCase _signInWithAppleUseCase;
  final SignInWithPasskeyUseCase _signInWithPasskeyUseCase;
  final RegisterPasskeyUseCase _registerPasskeyUseCase;
  final StoreAuthToken _storeAuthToken;
  final LoadPasskeyAvailability _loadPasskeyAvailability;

  AuthController(
    this._signInWithGoogleUseCase,
    this._signInWithAppleUseCase,
    this._signInWithPasskeyUseCase,
    this._registerPasskeyUseCase,
    this._storeAuthToken,
    this._loadPasskeyAvailability,
  ) : super(AuthState());

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

  String _resolveErrorMessage(Object error) {
    if (error is GoogleSignInException) {
      switch (error.code) {
        case GoogleSignInExceptionCode.canceled:
        case GoogleSignInExceptionCode.interrupted:
          return '';
        case GoogleSignInExceptionCode.clientConfigurationError:
        case GoogleSignInExceptionCode.providerConfigurationError:
          return 'Google sign-in is not configured correctly yet.';
        default:
          return "Google sign-in didn't finish. Try again?";
      }
    }

    if (error is SignInWithAppleAuthorizationException &&
        error.code == AuthorizationErrorCode.canceled) {
      return '';
    }

    if (error is SignInWithAppleNotSupportedException) {
      return 'Apple sign-in is not available on this device.';
    }

    if (error is PasskeyAuthCancelledException) {
      return '';
    }

    if (error is NoCredentialsAvailableException) {
      return 'No passkey was found for this account on this device.';
    }

    if (error is DomainNotAssociatedException) {
      return 'Passkeys are not configured for this build yet.';
    }

    if (error is PasskeyUnsupportedException ||
        error is DeviceNotSupportedException) {
      return "Passkeys aren't available on this device yet.";
    }

    if (error is TimeoutException) {
      return 'That took too long. Try again.';
    }

    final rawMessage = error.toString();
    final message = rawMessage.startsWith('Exception: ')
        ? rawMessage.substring('Exception: '.length)
        : rawMessage;
    if (message.isNotEmpty && message != 'Exception') {
      return message;
    }
    return "Something went wrong. Let's try that again.";
  }

  Future<AuthSessionResult?> _runSessionAction(
    AuthAction action,
    Future<AuthSessionResult> Function() callback,
  ) async {
    state = state.copyWith(
      isLoading: true,
      activeAction: action,
      clearError: true,
      clearNavigation: true,
    );

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
      final errorMessage = _resolveErrorMessage(e);
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
      final errorMessage = _resolveErrorMessage(e);
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
      () => _signInWithGoogleUseCase(),
    );
  }

  Future<AuthSessionResult?> signInWithApple() {
    return _runSessionAction(
      AuthAction.signInWithApple,
      () => _signInWithAppleUseCase(),
    );
  }

  Future<AuthSessionResult?> signInWithPasskey() {
    return _runSessionAction(
      AuthAction.signInWithPasskey,
      () => _signInWithPasskeyUseCase(),
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
