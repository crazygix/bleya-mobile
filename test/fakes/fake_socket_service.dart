import 'dart:async';

import 'package:bleya/domain/entities/room.dart';
import 'package:bleya/services/socket_service.dart';

/// Socket double that never opens a connection. Tests deliver server events
/// with [emit] and join failures with [failJoin]. Claims are the real
/// [SocketService] ones, so [claims] and [openChat] follow the screens, and
/// a claimed room that isn't joined fails after 10 s as not connected.
///
/// It behaves like the backend for sends: a failed send is reported as an
/// 'error' event and then in the acknowledgement.
class FakeSocketService extends SocketService {
  FakeSocketService() {
    super.joinFailures.listen(_joinFailures.add);
  }

  final Map<String, List<Function(Map<String, dynamic>)>> listeners = {};
  final List<SendMessageResult> sendResults = [];
  final List<String> sentTexts = [];
  final List<String> sentRoomIds = [];
  final List<String> activatedRoomIds = [];
  final List<String> snapshotRequests = [];
  final List<String> retriedJoins = [];
  final StreamController<RoomJoinFailure> _joinFailures =
      StreamController<RoomJoinFailure>.broadcast(sync: true);
  final StreamController<void> _resyncRequests =
      StreamController<void>.broadcast(sync: true);

  /// How often a list asked to catch up on the first connect.
  int resyncOnConnectRequests = 0;

  /// Runs while a send waits for its acknowledgement.
  void Function()? duringSend;

  /// While set, [ensureConnectedForUserChannel] waits for it to complete, as
  /// a connect attempt in progress does.
  Completer<void>? pendingConnect;

  /// How many handlers are registered for [event].
  int listenerCount(String event) => listeners[event]?.length ?? 0;

  void emit(String event, Map<String, dynamic> data) {
    for (final listener in List.of(listeners[event] ?? const [])) {
      listener(data);
    }
  }

  /// Reports that [roomId] couldn't be joined.
  void failJoin(String roomId, SocketErrorData error) {
    _joinFailures.add(RoomJoinFailure(roomId: roomId, error: error));
  }

  @override
  Stream<RoomJoinFailure> get joinFailures => _joinFailures.stream;

  /// Asks the lists to catch up, as the service does after a reconnect.
  void requestResync() => _resyncRequests.add(null);

  @override
  Stream<void> get resyncRequests => _resyncRequests.stream;

  @override
  void requestResyncOnConnect() {
    resyncOnConnectRequests++;
    super.requestResyncOnConnect();
  }

  @override
  Future<void> ensureConnectedForUserChannel() async {
    await pendingConnect?.future;
  }

  @override
  dynamic addListener(String event, Function(Map<String, dynamic>) callback) {
    listeners.putIfAbsent(event, () => []).add(callback);
    return callback;
  }

  @override
  void removeListener(String event, dynamic handler) {
    listeners[event]?.remove(handler);
  }

  @override
  void activateClaim(RoomClaim claim) {
    activatedRoomIds.add(claim.room.id);
    super.activateClaim(claim);
  }

  @override
  void requestRoomSnapshot(Room room) {
    snapshotRequests.add(room.id);
    super.requestRoomSnapshot(room);
  }

  @override
  void retryJoin(Room room) {
    retriedJoins.add(room.id);
    super.retryJoin(room);
  }

  @override
  Future<SendMessageResult> sendMessage(
    String text, {
    required Room room,
    String? parentMessageId,
  }) async {
    sentTexts.add(text);
    sentRoomIds.add(room.id);
    duringSend?.call();
    final result = sendResults.removeAt(0);
    final error = result.error;
    if (error != null) {
      emit('error', {
        'error': {'code': error.code, 'message': error.message},
      });
    }
    return result;
  }
}
