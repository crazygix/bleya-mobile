import '../../domain/repositories/user_repository.dart';

class UnblockUserUseCase {
  final UserRepository _repository;

  UnblockUserUseCase(this._repository);

  Future<void> call(String userId) => _repository.unblockUser(userId);
}
