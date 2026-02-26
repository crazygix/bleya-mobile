import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/user_profile.dart';

class SetUsernameUseCase {
  final AuthRepository _authRepository;

  SetUsernameUseCase(this._authRepository);

  Future<UserProfile> call({required String username}) async {
    return await _authRepository.setUsername(username: username);
  }
}
