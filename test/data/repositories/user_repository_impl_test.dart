import 'dart:io';

import 'package:bleya/data/repositories/user_repository_impl.dart';
import 'package:bleya/utils/app_errors.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_http_adapter.dart';

void main() {
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

  group('uploadProfileImage', () {
    test('sends the photo as profile.jpg, typed image/jpeg', () async {
      final server = FakeHttpAdapter(
        (_) async => jsonResponse(200, {
          'id': 'user-1',
          'username': 'ana',
          'profileImageUrl': 'https://cdn.test/avatars/user-1.jpg',
        }),
      );
      final repository = UserRepositoryImpl(fakeDio(server));

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
      expect(profile.profileImageUrl, 'https://cdn.test/avatars/user-1.jpg');
    });

    test("a photo the server refuses fails with the server's reason", () async {
      final server = FakeHttpAdapter(
        (_) async => apiErrorResponse(
          400,
          'VALIDATION_ERROR',
          "That image isn't allowed.",
        ),
      );
      final repository = UserRepositoryImpl(fakeDio(server));

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
