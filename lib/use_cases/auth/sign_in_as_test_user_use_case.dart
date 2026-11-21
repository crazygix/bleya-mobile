import '../../domain/entities/auth_result.dart';
import '../../domain/repositories/auth_repository.dart';

/// Dev builds only: signs in as a named test user on a local backend that has
/// DEV_LOGIN_ENABLED (see the backend's .env.example).
class SignInAsTestUserUseCase {
  final AuthRepository _authRepository;

  SignInAsTestUserUseCase(this._authRepository);

  Future<AuthSessionResult> call({required String username}) {
    return _authRepository.signInAsTestUser(username: username.trim());
  }
}
