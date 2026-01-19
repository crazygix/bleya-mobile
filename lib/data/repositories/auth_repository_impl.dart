import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/errors/api_error_mapper.dart';
import '../../domain/repositories/auth_repository.dart';

/// Data layer implementation of AuthRepository
/// Handles all Dio/network concerns and JSON parsing
class AuthRepositoryImpl implements AuthRepository {
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  AuthRepositoryImpl(this._dio, this._secureStorage);

  @override
  Future<Map<String, dynamic>> requestCode({required String phone}) async {
    try {
      final response = await _dio.post(
        '/auth/request-code',
        data: {'phoneNumber': phone},
      );
      if (kDebugMode) {
        print("Code sent: ${response.data["code"]}");
      }
      return {
        'codeSentAt': response.data['codeSentAt'] as int?,
      };
    } on DioException catch (e) {
      if (kDebugMode) {
        print('Auth repository error: $e');
      }
      throw ApiErrorMapper.mapDioError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> resendCode({required String phone}) async {
    try {
      final response = await _dio.post(
        '/auth/resend-code',
        data: {'phoneNumber': phone},
      );
      if (kDebugMode) {
        print("Code resent: ${response.data["code"]}");
      }
      return {
        'codeSentAt': response.data['codeSentAt'] as int?,
      };
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> verifyCode({
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
      return {
        'token': token,
        'requiresUsername': requiresUsername,
      };
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
      if (e.response?.statusCode == 400) {
        return false;
      }
      return false;
    }
  }

  @override
  Future<void> setUsername({required String username}) async {
    try {
      await _dio.post(
        '/auth/set-username',
        data: {'username': username},
      );
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> getMyInfo() async {
    try {
      final response = await _dio.get('/auth/me');
      return response.data;
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
