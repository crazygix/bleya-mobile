import '../../domain/entities/auth_result.dart';
import '../../domain/repositories/auth_repository.dart';

class RequestCodeUseCase {
  final AuthRepository _authRepository;

  RequestCodeUseCase(this._authRepository);

  Future<CodeRequestResult> call({required String phone}) async {
    return await _authRepository.requestCode(phone: phone);
  }
}
