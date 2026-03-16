import '../../domain/entities/auth_result.dart';
import '../../domain/repositories/auth_repository.dart';

class SignInWithGoogleUseCase {
  final AuthRepository _authRepository;

  SignInWithGoogleUseCase(this._authRepository);

  Future<AuthSessionResult> call() async {
    return _authRepository.signInWithGoogle();
  }
}
