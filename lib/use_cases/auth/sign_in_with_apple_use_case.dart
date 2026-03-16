import '../../domain/entities/auth_result.dart';
import '../../domain/repositories/auth_repository.dart';

class SignInWithAppleUseCase {
  final AuthRepository _authRepository;

  SignInWithAppleUseCase(this._authRepository);

  Future<AuthSessionResult> call() async {
    return _authRepository.signInWithApple();
  }
}
