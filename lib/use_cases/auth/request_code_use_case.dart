import '../../domain/repositories/auth_repository.dart';

class RequestCodeUseCase {
  final AuthRepository _authRepository;

  RequestCodeUseCase(this._authRepository);

  Future<Map<String, dynamic>> call({required String phone}) async {
    return await _authRepository.requestCode(phone: phone);
  }
}
