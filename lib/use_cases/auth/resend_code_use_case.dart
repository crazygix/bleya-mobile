import '../../domain/repositories/auth_repository.dart';

class ResendCodeUseCase {
  final AuthRepository _authRepository;

  ResendCodeUseCase(this._authRepository);

  Future<Map<String, dynamic>> call({required String phone}) async {
    return await _authRepository.resendCode(phone: phone);
  }
}
