import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bleya/use_cases/user/get_profile_use_case.dart';
import 'package:bleya/use_cases/user/upload_profile_image_use_case.dart';
import 'package:bleya/use_cases/user/get_user_by_id_use_case.dart';
import 'package:bleya/use_cases/user/update_profile_use_case.dart';
import 'package:bleya/use_cases/user/get_blocked_users_use_case.dart';
import 'package:bleya/domain/entities/user_profile.dart';
import 'package:bleya/domain/entities/blocked_user.dart';
import '../mocks.dart';

void main() {
  late MockUserRepository mockRepo;

  setUpAll(() {
    registerFallbackValue(MockFile());
  });

  setUp(() {
    mockRepo = MockUserRepository();
  });

  final testProfile = UserProfile(id: 'u1', username: 'alice');

  group('GetProfileUseCase', () {
    test('delegates to repository.getProfile', () async {
      when(() => mockRepo.getProfile()).thenAnswer((_) async => testProfile);
      final useCase = GetProfileUseCase(mockRepo);

      final result = await useCase();

      expect(result, testProfile);
      verify(() => mockRepo.getProfile()).called(1);
    });
  });

  group('UploadProfileImageUseCase', () {
    test('delegates to repository.uploadProfileImage', () async {
      final mockFile = MockFile();
      when(() => mockRepo.uploadProfileImage(any()))
          .thenAnswer((_) async => testProfile);
      final useCase = UploadProfileImageUseCase(mockRepo);

      final result = await useCase(mockFile);

      expect(result, testProfile);
      verify(() => mockRepo.uploadProfileImage(mockFile)).called(1);
    });
  });

  group('GetUserByIdUseCase', () {
    test('delegates to repository.getUserById', () async {
      when(() => mockRepo.getUserById(any()))
          .thenAnswer((_) async => testProfile);
      final useCase = GetUserByIdUseCase(mockRepo);

      final result = await useCase('u1');

      expect(result, testProfile);
      verify(() => mockRepo.getUserById('u1')).called(1);
    });
  });

  group('UpdateProfileUseCase', () {
    test('delegates to repository.updateProfile', () async {
      when(() => mockRepo.updateProfile(
            username: any(named: 'username'),
            bio: any(named: 'bio'),
          )).thenAnswer((_) async => testProfile);
      final useCase = UpdateProfileUseCase(mockRepo);

      final result = await useCase(username: 'bob', bio: 'hello');

      expect(result, testProfile);
      verify(() => mockRepo.updateProfile(username: 'bob', bio: 'hello'))
          .called(1);
    });
  });

  group('GetBlockedUsersUseCase', () {
    test('delegates to repository.getBlockedUsers', () async {
      final blockedUsers = [
        BlockedUser(
          id: 'u2',
          username: 'bob',
          bio: '',
          profileImageUrl: null,
          blockedAt: null,
        ),
      ];
      when(() => mockRepo.getBlockedUsers())
          .thenAnswer((_) async => blockedUsers);
      final useCase = GetBlockedUsersUseCase(mockRepo);

      final result = await useCase();

      expect(result, blockedUsers);
      verify(() => mockRepo.getBlockedUsers()).called(1);
    });
  });
}
