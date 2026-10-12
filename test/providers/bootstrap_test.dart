import 'package:bleya/domain/entities/user_profile.dart';
import 'package:bleya/providers/auth_providers.dart';
import 'package:bleya/providers/profile_providers.dart';
import 'package:bleya/providers/repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes/in_memory_secure_storage.dart';
import '../mocks.dart';

void main() {
  late MockUserRepository users;
  late InMemorySecureStorage storage;
  late ProviderContainer container;

  setUp(() {
    users = MockUserRepository();
    storage = InMemorySecureStorage();
    container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(storage),
        userRepositoryProvider.overrideWithValue(users),
      ],
    );
    addTearDown(container.dispose);
  });

  test('a signed-in launch fetches the profile once before the chat list',
      () async {
    storage.values['auth_token'] = 'stored-token';
    when(() => users.getProfile()).thenAnswer(
      (_) async => UserProfile(id: 'alice-id', username: 'alice'),
    );

    // What the launch screen does: wait for the session, then check the
    // username.
    expect(await container.read(bootstrapProvider.future), isTrue);
    final profile =
        await container.read(profileProvider.notifier).fetchProfile();
    await pumpEventQueue();

    expect(profile.username, 'alice');
    verify(() => users.getProfile()).called(1);
  });

  test('a launch whose profile check fails offline still opens the app',
      () async {
    storage.values['auth_token'] = 'stored-token';
    when(() => users.getProfile()).thenThrow(Exception('offline'));

    expect(await container.read(bootstrapProvider.future), isTrue);
  });
}
