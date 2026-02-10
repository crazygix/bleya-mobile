import '../../domain/entities/auth_result.dart';
import '../../domain/repositories/auth_repository.dart';

class ResendCodeUseCase {
  final AuthRepository _authRepository;

  ResendCodeUseCase(this._authRepository);

  Future<CodeRequestResult> call({required String phone}) async {
    return await _authRepository.resendCode(phone: phone);
  }
}
