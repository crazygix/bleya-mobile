import 'dart:io';
import '../../domain/repositories/user_repository.dart';

class UploadProfileImageUseCase {
  final UserRepository _userRepository;

  UploadProfileImageUseCase(this._userRepository);

  Future<Map<String, dynamic>> call(File imageFile) async {
    return await _userRepository.uploadProfileImage(imageFile);
  }
}
