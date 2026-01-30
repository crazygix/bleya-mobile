import 'dart:io';
import '../../domain/repositories/user_repository.dart';
import '../../domain/entities/user_profile.dart';

class UploadProfileImageUseCase {
  final UserRepository _userRepository;

  UploadProfileImageUseCase(this._userRepository);

  Future<UserProfile> call(File imageFile) async {
    return await _userRepository.uploadProfileImage(imageFile);
  }
}
