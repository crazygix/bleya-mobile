import 'package:bleya/providers/auth_providers.dart';
import 'package:bleya/providers/chat_providers.dart';
import 'package:bleya/providers/use_case_providers.dart';
import 'package:bleya/use_cases/room/get_room_members_use_case.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetRoomMembersUseCase extends Mock implements GetRoomMembersUseCase {}

List<RoomMember> _members(int from, int to) => [
      for (var i = from; i < to; i++)
        RoomMember(id: 'm$i', username: 'user$i', bio: '', profileImageUrl: ''),
    ];

void main() {
  late MockGetRoomMembersUseCase getMembers;
  late ProviderContainer container;
  ProviderSubscription<Object?>? subscription;

  setUp(() {
    getMembers = MockGetRoomMembersUseCase();
    container = ProviderContainer(
      overrides: [
        tokenProvider.overrideWith((ref) => 'token'),
        getRoomMembersUseCaseProvider.overrideWithValue(getMembers),
      ],
    );
  });

  tearDown(() async {
    subscription?.close();
    subscription = null;
    await pumpEventQueue();
    container.dispose();
  });

  // Opens the member list (the controller loads its first page right away).
  Future<void> open() async {
    subscription = container.listen(roomMembersProvider('room-1'), (_, __) {});
    await pumpEventQueue();
  }

  void answerPages(Map<int, List<RoomMember>> pagesByOffset) {
    when(() => getMembers(
          'room-1',
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        )).thenAnswer((invocation) async {
      final offset = invocation.namedArguments[#offset] as int;
      return pagesByOffset[offset] ?? const [];
    });
  }

  RoomMembersState? loaded() =>
      container.read(roomMembersProvider('room-1')).valueOrNull;

  test('a full first page means more members may follow', () async {
    answerPages({0: _members(0, 100)});

    await open();

    expect(loaded()?.members, hasLength(100));
    expect(loaded()?.hasMore, isTrue);
  });

  test('loads the next page and stops at a short page, skipping repeats',
      () async {
    // Someone left between the two requests, so m99 comes back again.
    answerPages({0: _members(0, 100), 100: _members(99, 139)});
    await open();

    await container.read(roomMembersProvider('room-1').notifier).loadMore();

    expect(loaded()?.members, hasLength(139));
    expect(loaded()?.members.map((m) => m.id).toSet(), hasLength(139));
    expect(loaded()?.hasMore, isFalse);
    verify(() => getMembers('room-1', limit: 100, offset: 100)).called(1);
  });

  test('keeps the loaded members when the next page fails', () async {
    answerPages({0: _members(0, 100)});
    await open();
    when(() => getMembers('room-1', limit: 100, offset: 100))
        .thenThrow(Exception('offline'));

    await container.read(roomMembersProvider('room-1').notifier).loadMore();

    expect(loaded()?.members, hasLength(100));
    expect(loaded()?.hasMore, isTrue);
    expect(loaded()?.isLoadingMore, isFalse);
  });
}
