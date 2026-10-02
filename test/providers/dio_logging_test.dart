import 'dart:async';
import 'dart:io';

import 'package:bleya/providers/auth_providers.dart';
import 'package:bleya/providers/repository_providers.dart';
import 'package:bleya/services/data_export_file.dart';
import 'package:bleya/services/push_messaging_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes/fake_app_badge_service.dart';
import '../fakes/fake_http_adapter.dart';
import '../fakes/fake_socket_service.dart';
import '../fakes/in_memory_secure_storage.dart';
import '../mocks.dart';

class MockPushMessagingService extends Mock implements PushMessagingService {}

void main() {
  late Directory storageDir;
  late ProviderContainer container;

  setUp(() async {
    storageDir = await Directory.systemTemp.createTemp('bleya-dio-log-test');
    container = ProviderContainer(
      overrides: [
        cookieStoragePathProvider.overrideWithValue(storageDir.path),
        secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
        socketServiceProvider.overrideWithValue(FakeSocketService()),
        authRepositoryProvider.overrideWithValue(MockAuthRepository()),
        pushMessagingServiceProvider
            .overrideWithValue(MockPushMessagingService()),
        sessionCleanupDioProvider.overrideWithValue(
          fakeDio(FakeHttpAdapter((_) async => jsonResponse(200, {}))),
        ),
        dataExportFileProvider.overrideWithValue(
          DataExportFile(temporaryDirectory: () async => storageDir),
        ),
        appBadgeServiceProvider.overrideWithValue(FakeAppBadgeService()),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await storageDir.delete(recursive: true);
  });

  /// Everything printed while [body] runs.
  Future<String> printedDuring(Future<void> Function() body) async {
    final lines = <String>[];
    await runZoned(
      body,
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => lines.add(line),
      ),
    );
    return lines.join('\n');
  }

  test('debug logs show a sign-in request but none of its secrets', () async {
    final dio = container.read(dioProvider)
      ..httpClientAdapter = FakeHttpAdapter(
        (_) async => jsonResponse(200, {
          'token': 'secret-access-token',
          'requiresUsername': false,
        }),
      );

    final log = await printedDuring(() async {
      await dio.post(
        '/auth/provider-sign-in',
        data: {
          'provider': 'google',
          'idToken': 'secret-id-token',
          'rawNonce': 'secret-nonce',
        },
      );
    });

    // The request and its answer are in the log...
    expect(log, contains('/auth/provider-sign-in'));
    expect(log, contains('"token": "[REDACTED]"'));
    // ...but not what was sent, or the token that came back.
    expect(log, isNot(contains('secret-id-token')));
    expect(log, isNot(contains('secret-nonce')));
    expect(log, isNot(contains('secret-access-token')));
  });
}
