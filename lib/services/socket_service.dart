import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/environment.dart';
import '../data/dtos/message_dto.dart';
import '../data/dtos/notification_dto.dart';
import '../data/dtos/room_dto.dart';
import '../domain/entities/message.dart';
import '../domain/entities/notification.dart';
import '../domain/entities/room.dart';

class RoomJoinedEventData {
  final Room room;
  final List<Message> messages;
  final bool hasMore;
  final String? nextCursor;
  final DateTime? lastReadAt;

  const RoomJoinedEventData({
    required this.room,
    required this.messages,
    required this.hasMore,
    required this.nextCursor,
    required this.lastReadAt,
  });
}

class SocketErrorData {
  final String? code;
  final String message;

  const SocketErrorData({
    required this.code,
    required this.message,
  });
}

/// Outcome of `send_message`, taken from the server's acknowledgement.
class SendMessageResult {
  /// The stored message, when the server accepted it.
  final Message? message;

  /// Why the message wasn't stored.
  final SocketErrorData? error;

  const SendMessageResult.sent(this.message) : error = null;

  const SendMessageResult.failed(SocketErrorData this.error) : message = null;

  bool get isSent => error == null;
}

/// Why the server refused or ended the socket's session, as opposed to an
/// error about a single event (such as a rejected message).
enum SocketConnectionErrorKind {
  /// The access token was missing, invalid or expired: refresh, reconnect.
  authentication,

  /// The account is banned or suspended: stop and sign out.
  accountBlocked,

  /// A temporary backend problem: keep the session and retry later.
  serverUnavailable,
}

class SocketConnectionError implements Exception {
  final SocketConnectionErrorKind kind;
  final String message;

  const SocketConnectionError(this.kind, this.message);

  // Stable prefixes the backend puts on handshake rejections (server/socket.ts).
  static const _authenticationPrefix = 'Authentication error';
  static const _blockedPrefix = 'Account blocked:';
  static const _unavailablePrefix = 'Server unavailable:';
  static const _tokenExpiredCode = 'TOKEN_EXPIRED';

  static const defaultBlockedMessage =
      'Your account is no longer allowed to use Bleya.';

  /// Reads a socket `error` payload: a handshake rejection (`{message}`) or an
  /// event error (`{error: {code, message}}`). Returns null for errors that
  /// concern a single event.
  static SocketConnectionError? tryParse(dynamic payload) {
    String? code;
    Object? rawMessage = payload;
    if (payload is Map) {
      final nested = payload['error'];
      if (nested is Map) {
        code = nested['code']?.toString();
        rawMessage = nested['message'];
      } else {
        rawMessage = payload['message'];
      }
    }
    final message = rawMessage is String ? rawMessage.trim() : '';

    if (message.startsWith(_blockedPrefix)) {
      final reason = message.substring(_blockedPrefix.length).trim();
      return SocketConnectionError(
        SocketConnectionErrorKind.accountBlocked,
        reason.isEmpty ? defaultBlockedMessage : reason,
      );
    }
    if (code == _tokenExpiredCode ||
        message.startsWith(_authenticationPrefix)) {
      return SocketConnectionError(
        SocketConnectionErrorKind.authentication,
        message,
      );
    }
    if (message.startsWith(_unavailablePrefix)) {
      return SocketConnectionError(
        SocketConnectionErrorKind.serverUnavailable,
        message,
      );
    }
    return null;
  }

  @override
  String toString() => message;
}

class SocketService {
  static const notInRoomCode = 'NOT_IN_ROOM';
  static const notConnectedCode = 'NOT_CONNECTED';
  static const sendTimeoutCode = 'SEND_TIMEOUT';

  static const _connectTimeout = Duration(seconds: 25);
  static const _sendAckTimeout = Duration(seconds: 10);
  // A connection that lasts this long resets the retry backoff.
  static const _stableConnection = Duration(seconds: 30);

  io.Socket? _socket;
  Room? _currentRoom;
  String? _currentToken;
  String? _activeThreadId;
  String? _desiredThreadId;
  bool _authRefreshInFlight = false;
  Room? _desiredRoom;

  /// Whether a screen has asked for the socket. Reconnects only happen while
  /// true; it's cleared when the user signs out.
  bool _wantsConnection = false;

  /// Single-flight connection attempt to prevent overlapping connect/reconnect calls.
  Completer<void>? _connectAttempt;
  Timer? _connectAttemptTimeout;

  Timer? _retryTimer;
  int _retryAttempt = 0;
  bool _retryRefreshesFirst = false;
  Timer? _stableConnectionTimer;
  int _consecutiveAuthRejections = 0;
  final Random _random = Random();

  /// Optional callback invoked when an authentication error is detected
  /// on the socket connection.
  ///
  /// Should refresh the token (and typically update token provider) and return
  /// the fresh access token, or null if refresh failed. When the session has
  /// ended it should also sign out, which clears the token here via
  /// [setToken]; otherwise the socket retries later.
  Future<String?> Function()? refreshToken;

  /// Invoked when the socket is rejected for a non-auth reason (a ban/suspend).
  /// Receives the server's reason. The wiring should surface it and log the user
  /// out so the client stops trying to reconnect into the same rejection.
  Future<void> Function(String message)? onFatalError;

  io.Socket? get socket => _socket;

  void setToken(String? token) {
    _currentToken = (token != null && token.isNotEmpty) ? token : null;
    // If token is cleared, disconnect but keep the socket instance (single socket).
    if (_currentToken == null) {
      _stopReconnecting();
      _socket?.disconnect();
      _currentRoom = null;
      _desiredRoom = null;
      _activeThreadId = null;
      _desiredThreadId = null;
      return;
    }
    // Ensure we have a socket instance ready; don't auto-join here.
    _ensureSocketInitialized();
    _updateHeaderToken(_currentToken!);
  }

  void _ensureSocketInitialized() {
    if (_socket != null) return;

    _socket = io.io(
      EnvironmentConfig.socketBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          // Called for every connect and reconnect, so the handshake always
          // carries the latest token. The backend reads handshake.auth first;
          // the header below is only a fallback.
          .setAuthFn((callback) => callback({'token': _currentToken ?? ''}))
          .setExtraHeaders(_authHeaders(_currentToken))
          .enableForceNew()
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      if (kDebugMode) {
        print('Socket connected');
      }
      _consecutiveAuthRejections = 0;
      _cancelRetry();
      _stableConnectionTimer?.cancel();
      _stableConnectionTimer = Timer(_stableConnection, () {
        _retryAttempt = 0;
      });
      _finishConnectAttempt();
      // If a room is desired (e.g., screen entered), join it after connect.
      final desired = _desiredRoom;
      if (desired != null) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_socket?.connected == true) {
            _doJoinRoom(desired);
          }
        });
      }
    });

    _socket!.onDisconnect((reason) {
      if (kDebugMode) {
        print('Socket disconnected ($reason)');
      }
      _stableConnectionTimer?.cancel();
      _activeThreadId = null;
      _currentRoom = null;

      // socket.io reconnects by itself after network drops, but not when the
      // server ends the connection. That happens on a ban, an expired token,
      // a deploy, or the per-user connection limit. Reconnect with backoff; the
      // handshake then says which (a ban signs the user out). The backoff
      // keeps devices over the connection limit from disconnecting each other
      // in a tight loop.
      if (reason == 'io server disconnect' && !_authRefreshInFlight) {
        _scheduleReconnect();
      }
    });

    // Handshake rejections (CONNECT_ERROR) arrive as the socket's 'error'
    // event. Note that Socket.onError() listens on the Manager instead, which
    // only reports transport errors.
    _socket!.on('error', _onSocketError);

    _socket!.onError((error) {
      if (kDebugMode) {
        print('Socket transport error: $error');
      }
    });

    _socket!.onConnectError((error) {
      if (kDebugMode) {
        print('Socket connection error: $error');
      }
      final rejection = SocketConnectionError.tryParse(error);
      if (rejection != null) {
        _handleConnectionError(rejection);
        return;
      }
      // Transport failure: socket.io keeps retrying with its own backoff.
      _finishConnectAttempt(error ?? Exception('connect_error'));
    });

    // Re-attach listeners that were registered before the socket existed.
    for (final entry in _eventHandlers.entries) {
      for (final handler in entry.value) {
        _socket!.on(entry.key, handler);
      }
    }
  }

  Map<String, dynamic> _authHeaders(String? token) {
    if (token == null || token.isEmpty) return <String, dynamic>{};
    return <String, dynamic>{'Authorization': 'Bearer $token'};
  }

  /// Engines created from now on (reconnects) send this token in the header
  /// fallback. The handshake itself always uses [setAuthFn].
  void _updateHeaderToken(String token) {
    final socket = _socket;
    if (socket == null) return;
    try {
      final manager = socket.io;
      final options = Map<String, dynamic>.from(
          manager.options ?? const <String, dynamic>{});
      options['extraHeaders'] = _authHeaders(token);
      manager.options = options;
    } catch (_) {
      // Best effort: the handshake auth carries the token anyway.
    }
  }

  /// Handles [payload] as if the server had sent it as a socket 'error'.
  @visibleForTesting
  void handleSocketErrorForTesting(dynamic payload) => _onSocketError(payload);

  void _onSocketError(dynamic data) {
    final rejection = SocketConnectionError.tryParse(data);
    if (rejection == null) {
      // An error about one event (e.g. a rejected message); the screens that
      // listen for 'error' handle those.
      return;
    }
    _handleConnectionError(rejection);
  }

  void _handleConnectionError(SocketConnectionError error) {
    if (kDebugMode) {
      print('Socket session error (${error.kind.name}): ${error.message}');
    }
    _finishConnectAttempt(error);

    switch (error.kind) {
      case SocketConnectionErrorKind.accountBlocked:
        // Refreshing would succeed and reconnect straight back into the same
        // ban, so stop and sign out with the server's reason.
        _stopReconnecting();
        _currentToken = null;
        _socket?.disconnect();
        final handler = onFatalError;
        if (handler != null) {
          unawaited(handler(error.message));
        }
      case SocketConnectionErrorKind.authentication:
        _consecutiveAuthRejections++;
        if (_consecutiveAuthRejections > 1) {
          // A freshly refreshed token was rejected too: back off instead of
          // refreshing in a loop.
          _scheduleReconnect(refreshFirst: true);
        } else {
          unawaited(_refreshAndReconnect());
        }
      case SocketConnectionErrorKind.serverUnavailable:
        // A temporary backend or database problem, not an auth problem.
        _scheduleReconnect();
    }
  }

  Future<void> _refreshAndReconnect() async {
    if (_authRefreshInFlight) return;
    final refresher = refreshToken;
    if (refresher == null) return;

    _authRefreshInFlight = true;
    String? newToken;
    try {
      newToken = await refresher();
    } catch (_) {
      newToken = null;
    } finally {
      _authRefreshInFlight = false;
    }

    if (newToken != null && newToken.isNotEmpty) {
      setToken(newToken);
      if (_wantsConnection) {
        await _ensureConnected().catchError((_) {});
      }
    } else if (_currentToken != null) {
      // Refresh temporarily unavailable (offline, server error). If the
      // session had ended, the app has signed out and cleared the token.
      _scheduleReconnect(refreshFirst: true);
    }
  }

  void _scheduleReconnect({bool refreshFirst = false}) {
    _retryRefreshesFirst = _retryRefreshesFirst || refreshFirst;
    if (!_wantsConnection || _currentToken == null) return;
    if (_retryTimer?.isActive ?? false) return;

    final delay = _retryDelay(_retryAttempt++);
    if (kDebugMode) {
      print('Socket reconnect in ${delay.inMilliseconds} ms');
    }
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (!_wantsConnection || _currentToken == null) return;
      if (_socket?.connected == true) return;
      final refreshFirst = _retryRefreshesFirst;
      _retryRefreshesFirst = false;
      if (refreshFirst) {
        unawaited(_refreshAndReconnect());
      } else {
        unawaited(_ensureConnected().catchError((_) {}));
      }
    });
  }

  /// 1 s, 2 s, 4 s ... capped at 60 s, plus up to 30% jitter.
  Duration _retryDelay(int attempt) {
    final seconds = min(60, 1 << min(attempt, 6));
    final jitter = _random.nextDouble() * 0.3 * seconds;
    return Duration(milliseconds: ((seconds + jitter) * 1000).round());
  }

  void _cancelRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryRefreshesFirst = false;
  }

  void _stopReconnecting() {
    _wantsConnection = false;
    _cancelRetry();
    _retryAttempt = 0;
    _consecutiveAuthRejections = 0;
    _stableConnectionTimer?.cancel();
    _finishConnectAttempt(StateError('Socket stopped'));
  }

  void disconnect() {
    _stopReconnecting();
    if (_currentRoom != null) {
      leaveRoom();
    }
    for (final event in _eventHandlers.keys.toList()) {
      for (final handler in _eventHandlers[event]!) {
        _socket?.off(event, handler);
      }
    }
    _eventHandlers.clear();
    _socket?.disconnect();
    _socket = null;
    _currentRoom = null;
    _desiredRoom = null;
    _activeThreadId = null;
    _desiredThreadId = null;
    _currentToken = null;
  }

  /// Joins [room] once connected. With [force], joins again even if the app
  /// thinks it's already in the room (the server says it isn't).
  Future<void> joinRoom(Room room, {bool force = false}) async {
    _desiredRoom = room;
    if (force) {
      if (_currentRoom?.id == room.id) {
        _currentRoom = null;
      }
      // Joining resets the server's open thread; send it again after the join.
      _activeThreadId = null;
    }

    if (_currentToken == null || _currentToken!.isEmpty) {
      if (kDebugMode) {
        print('No token available, cannot join room');
      }
      return;
    }

    _wantsConnection = true;
    _ensureSocketInitialized();
    try {
      await _ensureConnected();
    } catch (e) {
      // onConnect joins the desired room once a retry gets through.
      if (kDebugMode) {
        print('Socket not connected, will join ${room.id} later: $e');
      }
      return;
    }

    // If we are connected, attempt join.
    _doJoinRoom(room);
  }

  /// Ensure the socket is connected using the current token without
  /// joining any specific chat room. Used for per-user channels such
  /// as dashboard updates. Returns once connected or once the attempt has
  /// failed; listeners can be registered either way and survive reconnects.
  Future<void> ensureConnectedForUserChannel() async {
    if (_currentToken == null || _currentToken!.isEmpty) {
      if (kDebugMode) {
        print('⚠️ SocketService: No token available, cannot connect socket');
      }
      return;
    }
    if (kDebugMode) {
      print('📡 SocketService: Ensuring connection for user channel...');
    }
    _wantsConnection = true;
    _ensureSocketInitialized();
    try {
      await _ensureConnected();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ SocketService: Connection attempt failed: $e');
      }
      return;
    }
    if (kDebugMode) {
      print(
          '✅ SocketService: Connected for user channel (connected=${_socket?.connected})');
    }
  }

  /// Connects with the current token. Completes on connect and fails on a
  /// rejection, a connection error or a timeout, so no caller waits forever.
  Future<void> _ensureConnected() {
    // Single-flight: multiple joinRoom calls should share one connect attempt.
    final existing = _connectAttempt;
    if (existing != null) return existing.future;

    final socket = _socket;
    if (socket == null) {
      return Future.error(StateError('Socket not initialized'));
    }
    if (socket.connected == true) {
      return Future.value();
    }
    final token = _currentToken;
    if (token == null || token.isEmpty) {
      return Future.error(StateError('Missing token'));
    }

    final attempt = Completer<void>();
    // Callers may not wait for the result; don't report it as unhandled.
    attempt.future.ignore();
    _connectAttempt = attempt;
    _connectAttemptTimeout = Timer(_connectTimeout, () {
      _finishConnectAttempt(TimeoutException('Socket connection timed out'));
    });

    _updateHeaderToken(token);
    socket.connect();
    return attempt.future;
  }

  void _finishConnectAttempt([Object? error]) {
    final attempt = _connectAttempt;
    _connectAttempt = null;
    _connectAttemptTimeout?.cancel();
    _connectAttemptTimeout = null;
    if (attempt == null || attempt.isCompleted) return;
    if (error == null) {
      attempt.complete();
    } else {
      attempt.completeError(error);
    }
  }

  void _doJoinRoom(Room room) {
    final wasInDifferentRoom =
        _currentRoom != null && _currentRoom?.id != room.id;
    if (wasInDifferentRoom) {
      _activeThreadId = null;
      _desiredThreadId = null;
    }

    if (_currentRoom?.id == room.id) {
      if (kDebugMode) {
        print('[Room] Already in $room, skipping');
      }
      _emitOpenThreadIfNeeded();
      return;
    }

    if (_currentRoom != null) {
      if (kDebugMode) {
        print('[Room] Leaving $_currentRoom');
      }
      _socket?.emit('leave_room');
    }

    _currentRoom = room;
    _socket?.emit('join_room', {'roomId': room.id});
    if (kDebugMode) {
      print('[Room] Joining $room');
    }
  }

  /// Called when room_joined event is received to confirm we're in the room
  void onRoomJoinedConfirmed(Room room) {
    if (_currentRoom?.id == room.id) {
      _currentRoom = room; // Update with server data
      if (kDebugMode) {
        print('[Room] Joined $room');
      }
    } else {
      if (kDebugMode) {
        print(
            '[Room] Warning: room_joined for ${room.id} but current is ${_currentRoom?.id}');
      }
      _currentRoom = room;
    }

    _emitOpenThreadIfNeeded();
  }

  void leaveRoom([String? specificRoomId]) {
    // The screen is gone, so don't rejoin on the next reconnect: joining adds
    // the room back to the user's rooms and mutes its push notifications.
    if (specificRoomId == null || _desiredRoom?.id == specificRoomId) {
      _desiredRoom = null;
    }

    if (specificRoomId != null) {
      if (_currentRoom?.id == specificRoomId) {
        if (kDebugMode) {
          print('[Room] Leaving $_currentRoom');
        }
        _socket?.emit('leave_room');
        _currentRoom = null;
        _activeThreadId = null;
        _desiredThreadId = null;
      } else {
        if (kDebugMode) {
          print(
              '[Room] Not in room $specificRoomId (currently in: ${_currentRoom?.id}), skipping');
        }
      }
    } else {
      if (_currentRoom != null) {
        if (kDebugMode) {
          print('[Room] Leaving $_currentRoom');
        }
        _socket?.emit('leave_room');
        _currentRoom = null;
        _activeThreadId = null;
        _desiredThreadId = null;
      }
    }
  }

  void openThread(String threadId) {
    final normalizedThreadId = threadId.trim();
    if (normalizedThreadId.isEmpty) {
      return;
    }

    _desiredThreadId = normalizedThreadId;
    _emitOpenThreadIfNeeded();
  }

  void closeThread() {
    if (_desiredThreadId == null) {
      return;
    }

    _desiredThreadId = null;
    _activeThreadId = null;
    if (_socket?.connected == true) {
      _socket?.emit('close_thread');
    }
  }

  /// Sends a message and waits for the server to confirm it was stored, so
  /// the caller can keep the draft when it wasn't.
  Future<SendMessageResult> sendMessage(
    String text, {
    String? parentMessageId,
  }) {
    final socket = _socket;
    if (socket == null || socket.connected != true) {
      return Future.value(const SendMessageResult.failed(SocketErrorData(
        code: notConnectedCode,
        message: "You're not connected right now. Try again in a moment.",
      )));
    }
    if (_currentRoom == null) {
      return Future.value(const SendMessageResult.failed(SocketErrorData(
        code: notInRoomCode,
        message: 'Not in a room. Reopen the chat and try again.',
      )));
    }

    final data = <String, dynamic>{'text': text};
    if (parentMessageId != null) {
      data['parentMessageId'] = parentMessageId;
    }

    final completer = Completer<SendMessageResult>();
    final timeout = Timer(_sendAckTimeout, () {
      if (completer.isCompleted) return;
      completer.complete(const SendMessageResult.failed(SocketErrorData(
        code: sendTimeoutCode,
        message: "Couldn't confirm your message was sent. Check your "
            'connection and try again.',
      )));
    });
    socket.emitWithAck('send_message', data, ack: ([dynamic response]) {
      timeout.cancel();
      if (!completer.isCompleted) {
        completer.complete(parseSendMessageAck(response));
      }
    });
    return completer.future;
  }

  /// Reads the `send_message` acknowledgement: `{ok: true, message}` or
  /// `{ok: false, error: {code, message}}`.
  SendMessageResult parseSendMessageAck(dynamic response) {
    final payload =
        response is List && response.isNotEmpty ? response.first : response;
    if (payload is! Map) {
      return const SendMessageResult.failed(SocketErrorData(
        code: null,
        message: "Couldn't send your message. Try again?",
      ));
    }

    final data = Map<String, dynamic>.from(payload);
    if (data['ok'] == true) {
      final rawMessage = data['message'];
      return SendMessageResult.sent(
        rawMessage is Map
            ? parseMessagePayload(Map<String, dynamic>.from(rawMessage))
            : null,
      );
    }
    return SendMessageResult.failed(parseErrorPayload(data));
  }

  void _emitOpenThreadIfNeeded() {
    final threadId = _desiredThreadId;
    if (threadId == null || _socket?.connected != true || _currentRoom == null) {
      return;
    }

    if (_activeThreadId == threadId) {
      return;
    }

    _socket?.emit('open_thread', {'threadId': threadId});
    _activeThreadId = threadId;
  }

  // Store registered handlers so we can remove specific ones
  final Map<String, List<dynamic>> _eventHandlers = {};

  Map<String, dynamic> _normalizePayload(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {'message': data?.toString() ?? ''};
  }

  RoomJoinedEventData? parseRoomJoinedPayload(Map<String, dynamic> data) {
    try {
      final roomData = data['room'];
      if (roomData is! Map) {
        return null;
      }
      final room = RoomDto.fromJson(Map<String, dynamic>.from(roomData));

      final rawMessages = data['messages'];
      final messages = rawMessages is List
          ? rawMessages
              .whereType<Map>()
              .map((payload) =>
                  MessageDto.fromJson(Map<String, dynamic>.from(payload)))
              .toList()
          : <Message>[];

      final pagination = data['pagination'];
      final paginationMap = pagination is Map
          ? Map<String, dynamic>.from(pagination)
          : const <String, dynamic>{};
      final hasMore = paginationMap['hasMore'] as bool? ?? false;
      final nextCursor = paginationMap['nextCursor'] as String?;
      final lastReadAtMs = data['lastReadAt'];
      final lastReadAt = lastReadAtMs is int
          ? DateTime.fromMillisecondsSinceEpoch(lastReadAtMs)
          : null;

      return RoomJoinedEventData(
        room: room,
        messages: messages,
        hasMore: hasMore,
        nextCursor: nextCursor,
        lastReadAt: lastReadAt,
      );
    } catch (_) {
      return null;
    }
  }

  Message? parseMessagePayload(Map<String, dynamic> data) {
    try {
      return MessageDto.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  SocketErrorData parseErrorPayload(Map<String, dynamic> data) {
    final rawError = data['error'];
    final errorMap =
        rawError is Map ? Map<String, dynamic>.from(rawError) : null;
    final errorCode = errorMap?['code']?.toString();
    final errorMsg = errorMap?['message']?.toString() ??
        data['message']?.toString() ??
        'An error occurred';

    return SocketErrorData(
      code: errorCode,
      message: errorMsg,
    );
  }

  Notification? parseNotificationPayload(Map<String, dynamic> data) {
    try {
      return NotificationDto.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  void onRoomJoined(Function(Map<String, dynamic>) callback) {
    addListener('room_joined', callback);
  }

  void onNewMessage(Function(Map<String, dynamic>) callback) {
    addListener('new_message', callback);
  }

  void onMessageRemoved(Function(Map<String, dynamic>) callback) {
    addListener('message_removed', callback);
  }

  void onError(Function(Map<String, dynamic>) callback) {
    addListener('error', callback);
  }

  void onNewNotification(Function(Map<String, dynamic>) callback) {
    if (kDebugMode) {
      print(
          '📡 SocketService: Registering onNewNotification handler (socket connected: ${_socket?.connected})');
    }
    addListener('new_notification', (data) {
      if (kDebugMode) {
        print(
            '📡 SocketService: onNewNotification handler called with data: $data');
      }
      callback(data);
    });
    if (kDebugMode) {
      print('✅ SocketService: onNewNotification handler registered');
    }
  }

  void onNewNotificationEntity(Function(Notification notification) callback) {
    onNewNotification((data) {
      final notification = parseNotificationPayload(data);
      if (notification != null) {
        callback(notification);
      }
    });
  }

  /// Registers [callback] for [event].
  /// Returns the handler that was registered, which should be stored and passed back to removeListener.
  ///
  /// 'error' listeners only get errors about single events; connection-level
  /// errors (handshake rejections, an expired session) are handled here.
  dynamic addListener(String event, Function(Map<String, dynamic>) callback) {
    void handler(dynamic data) {
      if (event == 'error' && SocketConnectionError.tryParse(data) != null) {
        return;
      }
      callback(_normalizePayload(data));
    }

    _socket?.on(event, handler);
    _eventHandlers.putIfAbsent(event, () => []).add(handler);
    return handler;
  }

  /// Remove a specific handler for an event using the handler returned from addListener or on* methods.
  void removeListener(String event, dynamic handler) {
    if (handler != null) {
      _socket?.off(event, handler);
      _eventHandlers[event]?.remove(handler);
    }
  }

  /// Remove all listeners registered through this service for an event (use
  /// with caution). The service's own connection handlers stay.
  void off(String event) {
    final handlers = _eventHandlers.remove(event) ?? const [];
    for (final handler in handlers) {
      _socket?.off(event, handler);
    }
  }
}
