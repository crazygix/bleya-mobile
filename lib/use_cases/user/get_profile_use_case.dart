import '../../domain/repositories/user_repository.dart';

class GetProfileUseCase {
  final UserRepository _userRepository;

  GetProfileUseCase(this._userRepository);

  Future<Map<String, dynamic>> call() async {
    return await _userRepository.getProfile();
  }
}
