import '../../domain/repositories/user_repository.dart';

class DeleteAccountUseCase {
  final UserRepository _repository;

  DeleteAccountUseCase(this._repository);

  Future<void> call() => _repository.deleteAccount();
}
