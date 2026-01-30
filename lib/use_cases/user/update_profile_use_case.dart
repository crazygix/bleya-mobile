import '../../domain/repositories/user_repository.dart';
import '../../domain/entities/user_profile.dart';

class UpdateProfileUseCase {
  final UserRepository _userRepository;

  UpdateProfileUseCase(this._userRepository);

  Future<UserProfile> call({
    String? username,
    String? bio,
  }) async {
    return await _userRepository.updateProfile(
      username: username,
      bio: bio,
    );
  }
}
