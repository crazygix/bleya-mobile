import '../../domain/repositories/auth_repository.dart';

class CheckUsernameUseCase {
  final AuthRepository _authRepository;

  CheckUsernameUseCase(this._authRepository);

  Future<bool> call({required String username}) async {
    return await _authRepository.checkUsername(username: username);
  }
}
