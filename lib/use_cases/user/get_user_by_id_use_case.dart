import '../../domain/repositories/user_repository.dart';

class GetUserByIdUseCase {
  final UserRepository _userRepository;

  GetUserByIdUseCase(this._userRepository);

  Future<Map<String, dynamic>> call(String userId) async {
    return await _userRepository.getUserById(userId);
  }
}
