import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/errors/api_error_mapper.dart';
import '../dtos/user_profile_dto.dart';
import '../../domain/entities/auth_result.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';

/// Data layer implementation of AuthRepository
/// Handles all Dio/network concerns and JSON parsing
class AuthRepositoryImpl implements AuthRepository {
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  AuthRepositoryImpl(this._dio, this._secureStorage);

  int? _parseNullableTimestamp(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  @override
  Future<CodeRequestResult> requestCode({required String phone}) async {
    try {
      final response = await _dio.post(
        '/auth/request-code',
        data: {'phoneNumber': phone},
      );
      if (kDebugMode) {
        // Intentionally kept for local/staging debugging only.
        // Do not enable or mirror this in production telemetry.
        print("Code sent: ${response.data["code"]}");
      }
      return CodeRequestResult(
        codeSentAt: _parseNullableTimestamp(response.data['codeSentAt']),
      );
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Auth repository error: $e');
      }
      throw ApiErrorMapper.mapDioError(e);
    }
  }

  @override
  Future<CodeRequestResult> resendCode({required String phone}) async {
    try {
      final response = await _dio.post(
        '/auth/resend-code',
        data: {'phoneNumber': phone},
      );
      if (kDebugMode) {
        // Intentionally kept for local/staging debugging only.
        // Do not enable or mirror this in production telemetry.
        print("Code resent: ${response.data["code"]}");
      }
      return CodeRequestResult(
        codeSentAt: _parseNullableTimestamp(response.data['codeSentAt']),
      );
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    }
  }

  @override
  Future<VerifyCodeResult> verifyCode({
    required String phone,
    required String code,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/verify-code',
        data: {
          'phoneNumber': phone,
          'code': code,
        },
      );
      final String token = response.data['token'];
      final bool requiresUsername = response.data['requiresUsername'] ?? false;
      await _secureStorage.write(key: 'auth_token', value: token);
      return VerifyCodeResult(
        token: token,
        requiresUsername: requiresUsername,
      );
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    }
  }

  @override
  Future<bool> checkUsername({required String username}) async {
    try {
      final response = await _dio.post(
        '/auth/check-username',
        data: {'username': username},
      );
      return response.data['available'] as bool? ?? false;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 400 || statusCode == 409) {
        return false;
      }
      throw ApiErrorMapper.mapDioError(e);
    }
  }

  @override
  Future<UserProfile> setUsername({required String username}) async {
    try {
      final response = await _dio.post(
        '/auth/set-username',
        data: {'username': username},
      );
      return UserProfileDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    }
  }

  @override
  Future<UserProfile> getMyInfo() async {
    try {
      final response = await _dio.get('/auth/me');
      return UserProfileDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    }
  }

  @override
  Future<String> refresh() async {
    try {
      final response = await _dio.post(
        '/auth/refresh',
        options: Options(
          extra: {'refresh': true},
        ),
      );
      final String token = response.data['token'];
      await _secureStorage.write(key: 'auth_token', value: token);
      return token;
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _dio.post(
        '/auth/logout',
        options: Options(
          extra: {'logout': true},
        ),
      );
    } catch (_) {}
    await _secureStorage.delete(key: 'auth_token');
  }
}
