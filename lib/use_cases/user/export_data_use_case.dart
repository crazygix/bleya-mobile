import '../../domain/repositories/user_repository.dart';

class ExportDataUseCase {
  final UserRepository _repository;

  ExportDataUseCase(this._repository);

  Future<Map<String, dynamic>> call() => _repository.exportMyData();
}
