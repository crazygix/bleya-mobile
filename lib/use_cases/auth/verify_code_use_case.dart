import '../../domain/repositories/auth_repository.dart';

class VerifyCodeUseCase {
  final AuthRepository _authRepository;

  VerifyCodeUseCase(this._authRepository);

  Future<Map<String, dynamic>> call({
    required String phone,
    required String code,
  }) async {
    return await _authRepository.verifyCode(phone: phone, code: code);
  }
}
