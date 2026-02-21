import 'dart:io';
import 'package:dio/dio.dart';
import '../../core/errors/api_error_mapper.dart';
import '../../domain/repositories/user_repository.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/blocked_user.dart';
import '../dtos/user_profile_dto.dart';
import '../dtos/blocked_user_dto.dart';

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

  @override
  Future<List<BlockedUser>> getBlockedUsers() async {
    try {
      final response = await _dio.get('/users/blocked');
      if (response.data is! List) {
        throw Exception('Invalid response format: expected list');
      }

      final payload = response.data as List<dynamic>;
      return payload
          .whereType<Map<String, dynamic>>()
          .map(BlockedUserDto.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    }
  }
}
