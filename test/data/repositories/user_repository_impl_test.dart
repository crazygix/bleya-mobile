import 'dart:io';

import 'package:bleya/data/repositories/user_repository_impl.dart';
import 'package:bleya/utils/app_errors.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_http_adapter.dart';
import '../../fixtures/api_fixtures.dart';

void main() {
  late FakeHttpAdapter server;
  late UserRepositoryImpl repository;

  /// Answers every request with [body].
  void respondWith(Object body) {
    server = FakeHttpAdapter((_) async => jsonResponse(200, body));
    repository = UserRepositoryImpl(fakeDio(server));
  }

  test('GET /users/me', () async {
    respondWith(myProfileJson());

    final profile = await repository.getProfile();

    final request = server.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/users/me');
    expect(profile.id, FixtureIds.me);
    expect(profile.username, 'mila');
    expect(
      profile.lastLogin,
      DateTime.fromMillisecondsSinceEpoch(FixtureTimes.lastLogin),
    );
  });

  test('PUT /users/profile sends only the fields given', () async {
    respondWith(myProfileJson(bio: 'Night owl.'));

    final profile = await repository.updateProfile(bio: 'Night owl.');

    final request = server.requests.single;
    expect(request.method, 'PUT');
    expect(request.path, '/users/profile');
    expect(request.data, {'bio': 'Night owl.'});
    expect(profile.bio, 'Night owl.');
  });

  group('getUserById', () {
    test('GET /users/:userId', () async {
      respondWith(publicProfileJson());

      final profile = await repository.getUserById(FixtureIds.otherUser);

      final request = server.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/users/${FixtureIds.otherUser}');
      expect(profile.username, 'ana');
      expect(profile.lastLogin, isNull);
    });

    test('a deleted account fails as not found', () async {
      server = FakeHttpAdapter(
        (_) async => apiErrorResponse(404, 'USER_NOT_FOUND', 'User not found'),
      );
      repository = UserRepositoryImpl(fakeDio(server));

      await expectLater(
        repository.getUserById(FixtureIds.otherUser),
        throwsA(isA<NotFoundError>()),
      );
    });
  });

  group('getBlockedUsers', () {
    test('GET /users/blocked skips entries that are not users', () async {
      respondWith([blockedUserJson(), null, 'unexpected']);

      final users = await repository.getBlockedUsers();

      final request = server.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/users/blocked');
      expect(users.single.id, FixtureIds.otherUser);
      expect(
        users.single.blockedAt,
        DateTime.fromMillisecondsSinceEpoch(FixtureTimes.read),
      );
    });

    test('fails on a response that is not a list', () async {
      respondWith({'users': []});

      await expectLater(repository.getBlockedUsers(), throwsException);
    });
  });

  test('DELETE /users/me', () async {
    respondWith(deleteAccountJson());

    await repository.deleteAccount();

    final request = server.requests.single;
    expect(request.method, 'DELETE');
    expect(request.path, '/users/me');
  });

  test('GET /users/me/export returns the whole export', () async {
    respondWith(dataExportJson());

    final export = await repository.exportMyData();

    final request = server.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/users/me/export');
    expect(export, dataExportJson());
  });

  test('POST /users/:userId/block', () async {
    respondWith(userBlockResultJson(blocked: true));

    await repository.blockUser(FixtureIds.otherUser);

    final request = server.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/users/${FixtureIds.otherUser}/block');
    expect(request.data, isNull);
  });

  test('POST /users/:userId/unblock', () async {
    respondWith(userBlockResultJson(blocked: false));

    await repository.unblockUser(FixtureIds.otherUser);

    final request = server.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/users/${FixtureIds.otherUser}/unblock');
  });

  group('uploadProfileImage', () {
    late Directory tempDir;
    late File photo;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('bleya-upload-test');
      // What image_picker leaves on Android for a HEIC photo: a JPEG that
      // kept the original name.
      photo = File('${tempDir.path}/scaled_IMG_1234.heic')
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('sends the photo as profile.jpg, typed image/jpeg', () async {
      const photoUrl =
          'https://cdn.example.com/profiles/profile-7c2e4f10-5b3a-4d8e-a1f9-6e0b2c4d8a31.webp';
      respondWith(myProfileJson(profileImageUrl: photoUrl));

      final profile = await repository.uploadProfileImage(photo);

      final request = server.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/users/profile-image');
      final form = request.data as FormData;
      expect(form.fields, isEmpty);
      final part = form.files.single;
      expect(part.key, 'image');
      expect(part.value.filename, 'profile.jpg');
      expect(part.value.contentType?.mimeType, 'image/jpeg');
      expect(profile.profileImageUrl, photoUrl);
    });

    test("a photo the server refuses fails with the server's reason", () async {
      server = FakeHttpAdapter(
        (_) async => apiErrorResponse(
          400,
          'VALIDATION_ERROR',
          "That image isn't allowed.",
        ),
      );
      repository = UserRepositoryImpl(fakeDio(server));

      await expectLater(
        repository.uploadProfileImage(photo),
        throwsA(
          isA<BadRequestError>().having(
            (e) => e.getUserMessage(),
            'user message',
            "That image isn't allowed.",
          ),
        ),
      );
    });
  });
}
