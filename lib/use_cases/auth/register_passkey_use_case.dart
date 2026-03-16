import '../../domain/entities/auth_result.dart';
import '../../domain/repositories/auth_repository.dart';

class RegisterPasskeyUseCase {
  final AuthRepository _authRepository;

  RegisterPasskeyUseCase(this._authRepository);

  Future<AuthSecurityStatus> call() async {
    return _authRepository.registerPasskey();
  }
}
