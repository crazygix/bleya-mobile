import '../../domain/entities/auth_result.dart';
import '../../domain/repositories/auth_repository.dart';

class GetAuthSecurityStatusUseCase {
  final AuthRepository _authRepository;

  GetAuthSecurityStatusUseCase(this._authRepository);

  Future<AuthSecurityStatus> call() async {
    return _authRepository.getSecurityStatus();
  }
}
