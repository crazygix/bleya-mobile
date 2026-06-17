import '../../domain/repositories/user_repository.dart';

class BlockUserUseCase {
  final UserRepository _repository;

  BlockUserUseCase(this._repository);

  Future<void> call(String userId) => _repository.blockUser(userId);
}
