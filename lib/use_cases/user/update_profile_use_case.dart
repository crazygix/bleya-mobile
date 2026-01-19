import '../../domain/repositories/user_repository.dart';

class UpdateProfileUseCase {
  final UserRepository _userRepository;

  UpdateProfileUseCase(this._userRepository);

  Future<Map<String, dynamic>> call({
    String? username,
    String? bio,
  }) async {
    return await _userRepository.updateProfile(
      username: username,
      bio: bio,
    );
  }
}
