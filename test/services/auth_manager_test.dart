import 'package:bleya/domain/repositories/auth_repository.dart';
import 'package:bleya/providers/auth_providers.dart';
import 'package:bleya/providers/repository_providers.dart';
import 'package:bleya/providers/use_case_providers.dart';
import 'package:bleya/services/push_messaging_service.dart';
import 'package:bleya/services/socket_service.dart';
import 'package:bleya/use_cases/notification/unregister_push_token_use_case.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPushMessagingService extends Mock implements PushMessagingService {}

class MockSocketService extends Mock implements SocketService {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUnregisterPushTokenUseCase extends Mock
    implements UnregisterPushTokenUseCase {}

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPushMessagingService mockPushMessagingService;
  late MockSocketService mockSocketService;
  late MockAuthRepository mockAuthRepository;
  late MockUnregisterPushTokenUseCase mockUnregisterPushTokenUseCase;
  late MockFlutterSecureStorage mockSecureStorage;
  late ProviderContainer container;

  setUp(() {
    mockPushMessagingService = MockPushMessagingService();
    mockSocketService = MockSocketService();
    mockAuthRepository = MockAuthRepository();
    mockUnregisterPushTokenUseCase = MockUnregisterPushTokenUseCase();
    mockSecureStorage = MockFlutterSecureStorage();

    when(() => mockPushMessagingService.getToken())
        .thenAnswer((_) async => 'push-token');
    when(() => mockSocketService.disconnect()).thenReturn(null);
    when(() => mockAuthRepository.logout()).thenAnswer((_) async {});
    when(() => mockUnregisterPushTokenUseCase(token: 'push-token'))
        .thenAnswer((_) async {});
    when(
      () => mockSecureStorage.delete(
        key: any(named: 'key'),
        iOptions: null,
        aOptions: null,
        lOptions: null,
        webOptions: null,
        mOptions: null,
        wOptions: null,
      ),
    ).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        tokenProvider.overrideWith((ref) => 'auth-token'),
        pushMessagingServiceProvider
            .overrideWithValue(mockPushMessagingService),
        socketServiceProvider.overrideWithValue(mockSocketService),
        authRepositoryProvider.overrideWithValue(mockAuthRepository),
        unregisterPushTokenUseCaseProvider
            .overrideWithValue(mockUnregisterPushTokenUseCase),
        secureStorageProvider.overrideWithValue(mockSecureStorage),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('logout unregisters push token before clearing session state', () async {
    await container.read(authManagerProvider).logout();

    verifyInOrder([
      () => mockPushMessagingService.getToken(),
      () => mockUnregisterPushTokenUseCase(token: 'push-token'),
      () => mockSocketService.disconnect(),
      () => mockSecureStorage.delete(
            key: 'auth_token',
            iOptions: null,
            aOptions: null,
            lOptions: null,
            webOptions: null,
            mOptions: null,
            wOptions: null,
          ),
      () => mockAuthRepository.logout(),
    ]);

    expect(container.read(tokenProvider), isNull);
    expect(container.read(sessionVersionProvider), 1);
  });
}
