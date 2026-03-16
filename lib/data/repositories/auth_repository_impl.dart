import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/errors/api_error_mapper.dart';
import '../dtos/auth_dto.dart';
import '../dtos/user_profile_dto.dart';
import '../../domain/entities/auth_result.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../services/provider_auth_service.dart';
import '../../services/passkey_auth_service.dart';

/// Data layer implementation of AuthRepository
/// Handles all Dio/network concerns and JSON parsing
class AuthRepositoryImpl implements AuthRepository {
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;
  final ProviderAuthService _providerAuthService;
  final PasskeyAuthService _passkeyAuthService;

  AuthRepositoryImpl(
    this._dio,
    this._secureStorage,
    this._providerAuthService,
    this._passkeyAuthService,
  );

  Future<AuthSessionResult> _persistSessionResult(dynamic data) async {
    final result = authSessionResultFromJson(
      Map<String, dynamic>.from(data as Map? ?? const <String, dynamic>{}),
    );
    await _secureStorage.write(key: 'auth_token', value: result.token);
    return result;
  }

  Map<String, dynamic> _asJson(dynamic value) {
    return Map<String, dynamic>.from(
      value as Map? ?? const <String, dynamic>{},
    );
  }

  PasskeyRequestOptions _asPasskeyOptions(dynamic value) {
    final json = _asJson(value);
    return PasskeyRequestOptions(
      challengeId: json['challengeId'] as String? ?? '',
      payload: Map<String, dynamic>.from(
        json['options'] as Map? ?? const <String, dynamic>{},
      ),
    );
  }

  @override
  Future<AuthSessionResult> signInWithGoogle() async {
    try {
      final credential = await _providerAuthService.signInWithGoogle();
      final response = await _dio.post(
        '/auth/provider-sign-in',
        data: {
          'provider': credential.provider.apiValue,
          'idToken': credential.idToken,
          if (credential.rawNonce != null) 'rawNonce': credential.rawNonce,
          'platform': 'mobile',
        },
      );
      return _persistSessionResult(response.data);
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    }
  }

  @override
  Future<AuthSessionResult> signInWithApple() async {
    try {
      final credential = await _providerAuthService.signInWithApple();
      final response = await _dio.post(
        '/auth/provider-sign-in',
        data: {
          'provider': credential.provider.apiValue,
          'idToken': credential.idToken,
          if (credential.rawNonce != null) 'rawNonce': credential.rawNonce,
          'platform': 'mobile',
        },
      );
      return _persistSessionResult(response.data);
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    }
  }

  @override
  Future<AuthSessionResult> signInWithPasskey() async {
    try {
      final optionsResponse = await _dio.post('/auth/passkeys/authentication/options');
      final options = _asPasskeyOptions(optionsResponse.data);
      final credential = await _passkeyAuthService.authenticate(options);
      final verifyResponse = await _dio.post(
        '/auth/passkeys/authentication/verify',
        data: {
          'challengeId': options.challengeId,
          'response': credential,
        },
      );
      return _persistSessionResult(verifyResponse.data);
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    }
  }

  @override
  Future<AuthSecurityStatus> getSecurityStatus() async {
    try {
      final response = await _dio.get('/auth/identities');
      return authSecurityStatusFromJson(_asJson(response.data));
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    }
  }

  @override
  Future<AuthSecurityStatus> linkProvider(AuthProvider provider) async {
    try {
      final credential = provider == AuthProvider.apple
          ? await _providerAuthService.signInWithApple()
          : await _providerAuthService.signInWithGoogle();

      final response = await _dio.post(
        '/auth/identities/link',
        data: {
          'provider': credential.provider.apiValue,
          'idToken': credential.idToken,
          if (credential.rawNonce != null) 'rawNonce': credential.rawNonce,
        },
      );
      return authSecurityStatusFromJson(_asJson(response.data));
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    }
  }

  @override
  Future<AuthSecurityStatus> registerPasskey() async {
    try {
      final optionsResponse = await _dio.post('/auth/passkeys/registration/options');
      final options = _asPasskeyOptions(optionsResponse.data);
      final credential = await _passkeyAuthService.register(options);
      final verifyResponse = await _dio.post(
        '/auth/passkeys/registration/verify',
        data: {
          'challengeId': options.challengeId,
          'response': credential,
        },
      );
      return authSecurityStatusFromJson(_asJson(verifyResponse.data));
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
    await _providerAuthService.clearCachedProviderSession();
    await _secureStorage.delete(key: 'auth_token');
  }
}
