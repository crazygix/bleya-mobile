import '../../domain/repositories/user_repository.dart';
import '../../domain/entities/user_profile.dart';

class GetUserByIdUseCase {
  final UserRepository _userRepository;

  GetUserByIdUseCase(this._userRepository);

  Future<UserProfile> call(String userId) async {
    return await _userRepository.getUserById(userId);
  }
}
