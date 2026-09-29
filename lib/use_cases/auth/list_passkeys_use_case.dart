import '../../domain/entities/auth_result.dart';
import '../../domain/repositories/auth_repository.dart';

class ListPasskeysUseCase {
  final AuthRepository _authRepository;

  ListPasskeysUseCase(this._authRepository);

  Future<List<PasskeySummary>> call() async {
    return _authRepository.listPasskeys();
  }
}
