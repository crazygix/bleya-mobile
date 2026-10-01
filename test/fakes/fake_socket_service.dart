import 'dart:async';

import 'package:bleya/domain/entities/room.dart';
import 'package:bleya/services/socket_service.dart';

/// Socket double that never opens a connection. Tests deliver server events
/// with [emit].
///
/// It behaves like the backend for sends: a failed send is reported as an
/// 'error' event and then in the acknowledgement.
class FakeSocketService extends SocketService {
  final Map<String, List<Function(Map<String, dynamic>)>> listeners = {};
  final List<SendMessageResult> sendResults = [];
  final List<String> sentTexts = [];
  int forcedJoins = 0;

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
  Future<void> joinRoom(Room room, {bool force = false}) async {
    if (!force) return;
    forcedJoins++;
    emit('room_joined', {
      'room': {'id': room.id, 'name': room.name},
      'messages': const [],
      'pagination': {'hasMore': false},
    });
  }

  @override
  Future<SendMessageResult> sendMessage(
    String text, {
    String? parentMessageId,
  }) async {
    sentTexts.add(text);
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
