import 'dart:io';
import 'package:dio/dio.dart';
import '../../core/errors/api_error_mapper.dart';
import '../../domain/repositories/user_repository.dart';
import '../../domain/entities/user_profile.dart';
import '../dtos/user_profile_dto.dart';

/// Data layer implementation of UserRepository
/// Handles all Dio/network concerns and JSON parsing
class UserRepositoryImpl implements UserRepository {
  final Dio _dio;

  UserRepositoryImpl(this._dio);

  @override
  Future<UserProfile> getProfile() async {
    try {
      final response = await _dio.get('/users/me');
      return UserProfileDto.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    }
  }

  @override
  Future<UserProfile> updateProfile({
    String? username,
    String? bio,
  }) async {
    try {
      final response = await _dio.put(
        '/users/profile',
        data: {
          if (username != null) 'username': username,
          if (bio != null) 'bio': bio,
        },
      );
      return UserProfileDto.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    }
  }

  @override
  Future<UserProfile> uploadProfileImage(File imageFile) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.path.split('/').last,
        ),
      });

      final response = await _dio.post(
        '/users/profile-image',
        data: formData,
      );
      return UserProfileDto.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    }
  }

  @override
  Future<UserProfile> getUserById(String userId) async {
    try {
      final response = await _dio.get('/users/$userId');
      return UserProfileDto.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    }
  }
}
