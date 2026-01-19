import '../../domain/repositories/auth_repository.dart';

class SetUsernameUseCase {
  final AuthRepository _authRepository;

  SetUsernameUseCase(this._authRepository);

  Future<void> call({required String username}) async {
    await _authRepository.setUsername(username: username);
  }
}
