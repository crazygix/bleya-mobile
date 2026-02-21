import '../../domain/entities/blocked_user.dart';
import '../../domain/repositories/user_repository.dart';

class GetBlockedUsersUseCase {
  final UserRepository _userRepository;

  GetBlockedUsersUseCase(this._userRepository);

  Future<List<BlockedUser>> call() async {
    return await _userRepository.getBlockedUsers();
  }
}
