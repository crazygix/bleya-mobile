import '../../domain/repositories/user_repository.dart';
import '../../domain/entities/user_profile.dart';

class GetProfileUseCase {
  final UserRepository _userRepository;

  GetProfileUseCase(this._userRepository);

  Future<UserProfile> call() async {
    return await _userRepository.getProfile();
  }
}
