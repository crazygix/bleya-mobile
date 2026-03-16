import '../../domain/entities/auth_result.dart';
import '../../domain/repositories/auth_repository.dart';

class SignInWithPasskeyUseCase {
  final AuthRepository _authRepository;

  SignInWithPasskeyUseCase(this._authRepository);

  Future<AuthSessionResult> call() async {
    return _authRepository.signInWithPasskey();
  }
}
