import '../../domain/entities/auth_result.dart';
import '../../domain/repositories/auth_repository.dart';

class LinkAuthProviderUseCase {
  final AuthRepository _authRepository;

  LinkAuthProviderUseCase(this._authRepository);

  Future<AuthSecurityStatus> call({required AuthProvider provider}) async {
    return _authRepository.linkProvider(provider);
  }
}
