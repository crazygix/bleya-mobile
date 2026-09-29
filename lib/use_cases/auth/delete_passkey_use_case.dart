import '../../domain/entities/auth_result.dart';
import '../../domain/repositories/auth_repository.dart';

class DeletePasskeyUseCase {
  final AuthRepository _authRepository;

  DeletePasskeyUseCase(this._authRepository);

  Future<AuthSecurityStatus> call(String passkeyId) async {
    return _authRepository.deletePasskey(passkeyId);
  }
}
