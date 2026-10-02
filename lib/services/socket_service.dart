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

/// A chat screen's hold on a room: a room screen claims its room, a thread
/// screen its room and thread. The socket follows the newest claim that is
/// still held, so screens lower in the stack never pull it away.
class RoomClaim {
  RoomClaim._(this.room, this.threadId);

  final Room room;

  /// The thread the screen shows, or null for a room screen.
  final String? threadId;

  @override
  String toString() => threadId == null
      ? 'RoomClaim(${room.id})'
      : 'RoomClaim(${room.id}, thread $threadId)';
}

/// The chat on screen, derived from the claims.
@immutable
class OpenChat {
  const OpenChat({this.roomId, this.threadId});

  static const none = OpenChat();

  /// The room whose messages are on screen: a room screen, or a thread opened
  /// from that room's screen.
  final String? roomId;

  /// The thread on screen, if a thread screen is on top.
  final String? threadId;

  @override
  bool operator ==(Object other) =>
      other is OpenChat && other.roomId == roomId && other.threadId == threadId;

  @override
  int get hashCode => Object.hash(roomId, threadId);

  @override
  String toString() => 'OpenChat(room: $roomId, thread: $threadId)';
}

/// A chat the socket couldn't join: the server refused it, or it didn't open
/// in time.
class RoomJoinFailure {
  final String roomId;
  final SocketErrorData error;

  const RoomJoinFailure({required this.roomId, required this.error});

  /// Whether the server refused the join, as opposed to a timeout or a
  /// missing connection.
  bool get isRefusal =>
      error.code != SocketService.joinTimeoutCode &&
      error.code != SocketService.notConnectedCode;
}

/// Creates the socket.io socket; tests pass a fake.
typedef SocketFactory = io.Socket Function(
  String url,
  Map<String, dynamic> options,
);

/// A join_room request waiting for its answer. Compared by identity, so an
/// answer to an older request for the same room is told apart.
class _PendingJoin {
  final String roomId;

  _PendingJoin(this.roomId);
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
  static const joinTimeoutCode = 'JOIN_TIMEOUT';

  static const _connectTimeout = Duration(seconds: 25);
  static const _sendAckTimeout = Duration(seconds: 10);
  // A connection that lasts this long resets the retry backoff.
  static const _stableConnection = Duration(seconds: 30);
  // A chat that hasn't opened by then shows an error with Try again.
  static const _joinTimeout = Duration(seconds: 10);
  // How long a send waits for its chat to be joined again before retrying.
  static const _rejoinTimeout = Duration(seconds: 5);

  static const _notInRoomMessage =
      'Not in a room. Reopen the chat and try again.';
  static const _checkConnectionMessage = 'Check your connection and try again.';
  static const _notConnectedError = SocketErrorData(
    code: notConnectedCode,
    message: "You're not connected right now. Try again in a moment.",
  );

  SocketService({SocketFactory? socketFactory})
      : _socketFactory =
            socketFactory ?? ((url, options) => io.io(url, options));

  final SocketFactory _socketFactory;
  io.Socket? _socket;
  String? _currentToken;
  bool _authRefreshInFlight = false;

  // Room state. Screens hold claims, newest last; the socket follows the
  // newest one. The joined room is set only by room_joined.
  final List<RoomClaim> _claims = [];
  String? _joinedRoomId;
  _PendingJoin? _pendingJoin;
  // The thread the server was last told is open in the joined room.
  String? _openThreadId;
  // Not joined again until Try again, a reconnect or another claim on top.
  String? _failedJoinRoomId;
  Timer? _joinDeadline;
  bool _syncScheduled = false;
  bool _openChatUpdateScheduled = false;
  // Sends waiting for their chat to be joined again, one join per room.
  final Map<String, Completer<SocketErrorData?>> _joinWaiters = {};
  final ValueNotifier<OpenChat> _openChat = ValueNotifier(OpenChat.none);
  final StreamController<RoomJoinFailure> _joinFailures =
      StreamController<RoomJoinFailure>.broadcast();

  /// Whether a screen has asked for the socket. Reconnects only happen while
  /// true; it's cleared when the user signs out.
  bool _wantsConnection = false;

  // In the background the socket stays disconnected and nothing reconnects;
  // the claims and listeners stay for the return.
  bool _inForeground = true;

  // Catch-up for the chat list and Activity, see [resyncRequests].
  final StreamController<void> _resyncRequests =
      StreamController<void>.broadcast();
  // Connected at least once this session, so the next connect is a
  // reconnect.
  bool _hasConnected = false;
  // A list failed to load, so the session's first connect asks too.
  bool _resyncOnConnect = false;
  // Back in the foreground, until that return's reconnect completes or
  // fails.
  bool _awaitingReturnConnect = false;

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

  /// The chat on screen: the newest claim's room and thread. A thread screen
  /// counts its room as open only when it was opened from that room's screen.
  /// Updated in a microtask, so listeners never run during a build or a
  /// dispose.
  ValueListenable<OpenChat> get openChat => _openChat;

  /// Chats that couldn't be joined: the server's refusal, or no room_joined
  /// within 10 s (a timeout, or no connection). A failed chat isn't joined
  /// again until [retryJoin], a reconnect or another claim on top.
  Stream<RoomJoinFailure> get joinFailures => _joinFailures.stream;

  /// Asks the chat list and Activity to catch up over HTTP, since events sent
  /// while the socket was away never arrive. Fires once after each
  /// reconnect, and once per return to the foreground as soon as that
  /// return's reconnect completes or fails, so the lists catch up even where
  /// WebSockets are blocked. The session's first connect fires it only after
  /// [requestResyncOnConnect].
  Stream<void> get resyncRequests => _resyncRequests.stream;

  /// For a chat list or Activity that failed to load: [resyncRequests] also
  /// fires on the session's first connect, e.g. once the network is back
  /// after an offline start.
  void requestResyncOnConnect() {
    _resyncOnConnect = true;
  }

  /// Whether the app is in the foreground, as last set by [setForeground].
  @visibleForTesting
  bool get isInForeground => _inForeground;

  /// The claims held now, oldest first.
  @visibleForTesting
  List<RoomClaim> get claims => List.unmodifiable(_claims);

  /// Follows the app in and out of the foreground.
  ///
  /// In the background the socket disconnects, so the server no longer
  /// counts the user as present in the open chat and sends its pushes. The
  /// claims and listeners stay, and nothing reconnects until the app is
  /// back. Back in the foreground, it connects again if a screen wants the
  /// socket; the newest claim is then joined again, with its thread.
  void setForeground(bool foreground) {
    if (foreground == _inForeground) return;
    _inForeground = foreground;
    if (foreground) {
      _connectOnReturn();
    } else {
      _suspend();
    }
  }

  void _suspend() {
    if (kDebugMode) {
      print('Socket: app in the background, disconnecting');
    }
    _awaitingReturnConnect = false;
    // Nobody waits for a connect still in progress: it fails now, so the
    // return starts a new one.
    _finishConnectAttempt(StateError('App in the background'));
    _cancelRetry();
    _joinDeadline?.cancel();
    _joinDeadline = null;
    // Unlike disconnect(), this keeps the claims, the listeners and
    // _wantsConnection for the return.
    _socket?.disconnect();
  }

  void _connectOnReturn() {
    if (!_wantsConnection || _currentToken == null) return;
    if (kDebugMode) {
      print('Socket: app back in the foreground, reconnecting');
    }
    _ensureSocketInitialized();
    if (_socket?.connected == true) return;
    _awaitingReturnConnect = true;
    // The chat on top gets a fresh 10 s to open.
    _armJoinDeadline();
    // A token refresh still running connects once it has the new token.
    if (_authRefreshInFlight) return;
    unawaited(_ensureConnected().catchError((Object error) {
      // A reconnect, a refresh or Try again takes it from here.
      if (kDebugMode) {
        print('Socket not connected after the return: $error');
      }
    }));
  }

  /// The return's reconnect failed for now. The lists still catch up over
  /// HTTP.
  void _returnConnectFailed() {
    if (!_awaitingReturnConnect) return;
    _awaitingReturnConnect = false;
    _requestResync();
  }

  void _requestResync() {
    if (kDebugMode) {
      print('Socket: asking the chat list and Activity to catch up');
    }
    _resyncRequests.add(null);
  }

  void setToken(String? token) {
    _currentToken = (token != null && token.isNotEmpty) ? token : null;
    // If token is cleared, disconnect but keep the socket instance (single socket).
    if (_currentToken == null) {
      _stopReconnecting();
      _socket?.disconnect();
      _clearRooms();
      return;
    }
    // Ensure we have a socket instance ready; don't auto-join here.
    _ensureSocketInitialized();
    _updateHeaderToken(_currentToken!);
  }

  void _ensureSocketInitialized() {
    if (_socket != null) return;

    _socket = _socketFactory(
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
      // A new connection is in no room yet. A chat that failed gets another
      // try, and the newest claim decides which room to join, as it is now.
      _failedJoinRoomId = null;
      _scheduleSync();

      // Events sent while the socket was away never arrive, so the lists
      // catch up after a reconnect, a return to the foreground, or a first
      // load that failed.
      final resync =
          _hasConnected || _awaitingReturnConnect || _resyncOnConnect;
      _hasConnected = true;
      _awaitingReturnConnect = false;
      _resyncOnConnect = false;
      if (resync) {
        _requestResync();
      }
    });

    _socket!.onDisconnect((reason) {
      if (kDebugMode) {
        print('Socket disconnected ($reason)');
      }
      _stableConnectionTimer?.cancel();
      // The server forgets the room and thread with the connection. A join
      // still running here keeps its deadline, so the screen can't wait
      // forever for a connection that doesn't come back.
      _joinedRoomId = null;
      _pendingJoin = null;
      _openThreadId = null;

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

    // Registered before any screen's listener, so a join is confirmed here
    // before the screens handle its room_joined.
    _socket!.on('room_joined', _onRoomJoined);

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
      _returnConnectFailed();
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
    if (rejection != null) {
      _handleConnectionError(rejection);
      return;
    }

    // Other errors are about one event (e.g. a rejected message); the screens
    // that listen for 'error' handle those. Only NOT_IN_ROOM concerns the
    // room itself: the server lost it, so rejoin the newest claim's room. A
    // screen lower in the stack never pulls the socket back to its room.
    if (data is Map &&
        isNotInRoomError(parseErrorPayload(_normalizePayload(data)))) {
      if (kDebugMode) {
        print('[Room] Server says not in a room; rejoining the open chat');
      }
      _joinedRoomId = null;
      _openThreadId = null;
      _sync();
    }
  }

  /// Whether [error] says this socket isn't in a room (the server lost track
  /// of it, e.g. after a reconnect). Matched by code; the text is a fallback
  /// for older backends.
  static bool isNotInRoomError(SocketErrorData error) {
    return error.code == notInRoomCode ||
        error.message.contains('Not in a room');
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
    if (refresher == null) {
      _returnConnectFailed();
      return;
    }

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
      // In the background, connecting waits for the return.
      if (_wantsConnection && _inForeground) {
        await _ensureConnected().catchError((_) {});
      }
    } else if (_currentToken != null) {
      // Refresh temporarily unavailable (offline, server error). If the
      // session had ended, the app has signed out and cleared the token.
      _scheduleReconnect(refreshFirst: true);
    }
  }

  void _scheduleReconnect({bool refreshFirst = false}) {
    // Reconnecting has to wait for a retry; a return's lists catch up now.
    _returnConnectFailed();
    _retryRefreshesFirst = _retryRefreshesFirst || refreshFirst;
    if (!_wantsConnection || _currentToken == null || !_inForeground) return;
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
    // The session is over: the next one's first connect isn't a reconnect.
    _hasConnected = false;
    _resyncOnConnect = false;
    _awaitingReturnConnect = false;
  }

  void disconnect() {
    _stopReconnecting();
    for (final event in _eventHandlers.keys.toList()) {
      for (final handler in _eventHandlers[event]!) {
        _socket?.off(event, handler);
      }
    }
    _eventHandlers.clear();
    // The server leaves the room and thread with the connection.
    _socket?.disconnect();
    _socket = null;
    _clearRooms();
    _currentToken = null;
  }

  /// Signing out ends every claim, so no screen keeps the next session's
  /// socket in a room.
  void _clearRooms() {
    _claims.clear();
    _joinedRoomId = null;
    _pendingJoin = null;
    _openThreadId = null;
    _failedJoinRoomId = null;
    _joinDeadline?.cancel();
    _joinDeadline = null;
    final waiters = List.of(_joinWaiters.values);
    _joinWaiters.clear();
    for (final waiter in waiters) {
      if (!waiter.isCompleted) {
        waiter.complete(_notConnectedError);
      }
    }
    _scheduleOpenChatUpdate();
  }

  /// Holds [room] for a screen that just opened; a thread screen also passes
  /// its [threadId]. The socket joins the newest claim still held. Pass the
  /// result to [activateClaim] when the screen is back on top, and to
  /// [releaseClaim] when it closes.
  RoomClaim claimRoom(Room room, {String? threadId}) {
    final trimmedThreadId = threadId?.trim();
    final claim = RoomClaim._(
      room,
      trimmedThreadId == null || trimmedThreadId.isEmpty
          ? null
          : trimmedThreadId,
    );
    _updateClaims(() => _claims.add(claim));
    _connectForClaims();
    return claim;
  }

  /// Makes [claim] the newest again, when its screen is back on top. A
  /// released claim stays released.
  void activateClaim(RoomClaim claim) {
    if (!_claims.contains(claim) || identical(_claims.last, claim)) return;
    _updateClaims(() {
      _claims.remove(claim);
      _claims.add(claim);
    });
    _connectForClaims();
  }

  /// Ends [claim]; the socket falls back to the newest claim left, and leaves
  /// the room when none is left. Releasing twice does nothing.
  void releaseClaim(RoomClaim claim) {
    if (!_claims.contains(claim)) return;
    _updateClaims(() => _claims.remove(claim));
  }

  /// Ends every claim on [roomId], e.g. after the user left that room, so a
  /// reconnect can't join it again before its screens close.
  void releaseRoom(String roomId) {
    if (!_claims.any((claim) => claim.room.id == roomId)) return;
    _updateClaims(
      () => _claims.removeWhere((claim) => claim.room.id == roomId),
    );
  }

  /// Gets [room]'s messages for a screen that just opened while the socket
  /// is already in that room for another screen: it asks the server for the
  /// room again, so the screen gets its own room_joined.
  void requestRoomSnapshot(Room room) {
    if (_target?.room.id != room.id ||
        _joinedRoomId != room.id ||
        _pendingJoin != null) {
      // Not on top, or a room_joined is on its way anyway.
      return;
    }
    _joinedRoomId = null;
    _openThreadId = null;
    _scheduleSync();
  }

  /// Tries [room] again after its join failed (Try again on the chat).
  void retryJoin(Room room) {
    if (_failedJoinRoomId == room.id) {
      _failedJoinRoomId = null;
    }
    if (_target?.room.id != room.id) return;
    if (_joinedRoomId == room.id && _pendingJoin == null) {
      // Already in the room: ask for a fresh room_joined.
      _joinedRoomId = null;
      _openThreadId = null;
    }
    _restartJoinDeadline();
    _connectForClaims();
    _scheduleSync();
  }

  RoomClaim? get _target => _claims.isEmpty ? null : _claims.last;

  void _updateClaims(void Function() change) {
    final previousTarget = _target;
    change();
    if (!identical(_target, previousTarget)) {
      // Another screen is on top: its room may be tried again, with a fresh
      // deadline.
      _failedJoinRoomId = null;
      _restartJoinDeadline();
    }
    _scheduleSync();
    _scheduleOpenChatUpdate();
  }

  /// Starts connecting for the claims, if signed in and in the foreground.
  /// Once connected, [_sync] joins the newest claim.
  void _connectForClaims() {
    final token = _currentToken;
    if (token == null || token.isEmpty) return;
    _wantsConnection = true;
    _ensureSocketInitialized();
    if (!_inForeground || _socket?.connected == true) return;
    unawaited(_ensureConnected().catchError((Object error) {
      // A reconnect, a refresh or Try again takes it from here.
      if (kDebugMode) {
        print('Socket not connected, will join the open chat later: $error');
      }
    }));
  }

  /// Runs [_sync] once after the current change, so claims that change
  /// together (a screen closing as the one below comes back) send one join.
  void _scheduleSync() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    scheduleMicrotask(() {
      _syncScheduled = false;
      _sync();
    });
  }

  /// Moves the server to the newest claim, as the claims are when it runs:
  /// join its room, then open or close its thread once that room is
  /// confirmed, or leave when no claim is left. Does nothing while
  /// disconnected, so nothing is queued to be sent late; connecting runs it
  /// again.
  void _sync() {
    final socket = _socket;
    if (socket == null || socket.connected != true) return;

    final target = _target;
    if (target == null) {
      if (_joinedRoomId != null || _pendingJoin != null) {
        _leaveRoom();
      }
      return;
    }

    final roomId = target.room.id;
    final pending = _pendingJoin;
    if (pending != null) {
      // Wait for the join that's on its way. If it's for another room, ask
      // for this one instead: the server answers the latest request.
      if (pending.roomId != roomId && _failedJoinRoomId != roomId) {
        _emitJoin(target.room);
      }
      return;
    }
    if (_joinedRoomId != roomId) {
      if (_failedJoinRoomId != roomId) {
        _emitJoin(target.room);
      } else if (_joinedRoomId != null) {
        // The chat on top couldn't be joined. Don't stay behind in another
        // room, whose pushes would stay muted.
        _leaveRoom();
      }
      return;
    }

    // In the right room: open or close the thread to match.
    final threadId = target.threadId;
    if (threadId == _openThreadId) return;
    if (threadId == null) {
      socket.emit('close_thread');
    } else {
      socket.emit('open_thread', {'threadId': threadId});
    }
    _openThreadId = threadId;
  }

  void _emitJoin(Room room) {
    final request = _PendingJoin(room.id);
    _pendingJoin = request;
    _armJoinDeadline();
    if (kDebugMode) {
      print('[Room] Joining $room');
    }
    _socket!.emitWithAck(
      'join_room',
      {'roomId': room.id},
      ack: ([dynamic response]) => _onJoinAck(request, response),
    );
  }

  /// The server's answer to a join_room: `{ok: true}` after room_joined,
  /// `{ok: false, error}` when refused, or `{ok: false, superseded: true}`
  /// when a newer request replaced it. Older backends never answer.
  void _onJoinAck(_PendingJoin request, dynamic response) {
    // Only the latest join counts; answers to older ones are ignored.
    if (!identical(_pendingJoin, request)) return;
    final payload =
        response is List && response.isNotEmpty ? response.first : response;
    if (payload is! Map ||
        payload['ok'] == true ||
        payload['superseded'] == true) {
      return;
    }
    _failJoin(
      request.roomId,
      parseErrorPayload(Map<String, dynamic>.from(payload)),
    );
  }

  void _onRoomJoined(dynamic data) {
    final rawRoom = data is Map ? data['room'] : null;
    final roomId = rawRoom is Map ? rawRoom['id']?.toString() : null;
    if (roomId == null || roomId.isEmpty) return;

    if (kDebugMode) {
      print('[Room] Joined $roomId');
    }
    _joinedRoomId = roomId;
    // Joining closes the thread on the server.
    _openThreadId = null;
    if (_pendingJoin?.roomId == roomId) {
      _pendingJoin = null;
    }
    if (_failedJoinRoomId == roomId) {
      _failedJoinRoomId = null;
    }
    if (_target?.room.id == roomId) {
      _joinDeadline?.cancel();
      _joinDeadline = null;
    }
    _completeJoinWaiter(roomId, null);
    // Open the thread on top, or join another room if this one isn't on top
    // any more (an older join that finished late).
    _sync();
  }

  void _failJoin(String roomId, SocketErrorData error) {
    if (kDebugMode) {
      print("[Room] Couldn't join $roomId: ${error.message}");
    }
    _failedJoinRoomId = roomId;
    if (_pendingJoin?.roomId == roomId) {
      _pendingJoin = null;
    }
    if (_target?.room.id == roomId) {
      _joinDeadline?.cancel();
      _joinDeadline = null;
    }
    _completeJoinWaiter(roomId, error);
    _joinFailures.add(RoomJoinFailure(roomId: roomId, error: error));
    _sync();
  }

  void _leaveRoom() {
    if (kDebugMode) {
      print('[Room] Leaving ${_joinedRoomId ?? _pendingJoin?.roomId}');
    }
    _socket?.emit('leave_room');
    _joinedRoomId = null;
    _pendingJoin = null;
    _openThreadId = null;
  }

  void _restartJoinDeadline() {
    _joinDeadline?.cancel();
    _joinDeadline = null;
    _armJoinDeadline();
  }

  /// Gives the newest claim's room [_joinTimeout] to be joined, unless a
  /// deadline is already running for it. In the background the deadline
  /// waits for the return.
  void _armJoinDeadline() {
    if (_joinDeadline != null || !_inForeground) return;
    final target = _target;
    if (target == null ||
        target.room.id == _joinedRoomId ||
        target.room.id == _failedJoinRoomId) {
      return;
    }
    _joinDeadline = Timer(_joinTimeout, _onJoinDeadline);
  }

  void _onJoinDeadline() {
    _joinDeadline = null;
    final target = _target;
    if (target == null || target.room.id == _joinedRoomId) return;
    final connected = _socket?.connected == true;
    _failJoin(
      target.room.id,
      SocketErrorData(
        code: connected ? joinTimeoutCode : notConnectedCode,
        message: _checkConnectionMessage,
      ),
    );
  }

  /// Waits for [room] to be joined again, sharing one join among the sends
  /// that need it. Completes with null once joined, or with the join's error.
  Future<SocketErrorData?> _waitForRejoin(Room room) {
    final waiter = _joinWaiters.putIfAbsent(room.id, () {
      // The first send to notice asks for the room again, even if this side
      // thought the socket was in it.
      if (_joinedRoomId == room.id) {
        _joinedRoomId = null;
        _openThreadId = null;
      }
      return Completer<SocketErrorData?>();
    });
    if (_pendingJoin?.roomId != room.id) {
      // Sending is like Try again for a chat whose join failed.
      if (_failedJoinRoomId == room.id) {
        _failedJoinRoomId = null;
      }
      _scheduleSync();
    }
    return waiter.future;
  }

  void _completeJoinWaiter(String roomId, SocketErrorData? error) {
    final waiter = _joinWaiters.remove(roomId);
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete(error);
    }
  }

  void _scheduleOpenChatUpdate() {
    if (_openChatUpdateScheduled) return;
    _openChatUpdateScheduled = true;
    // Published after the current build or dispose, so listeners never run
    // in the middle of one.
    scheduleMicrotask(() {
      _openChatUpdateScheduled = false;
      _openChat.value = _currentOpenChat();
    });
  }

  OpenChat _currentOpenChat() {
    final target = _target;
    if (target == null) return OpenChat.none;
    final threadId = target.threadId;
    if (threadId == null) return OpenChat(roomId: target.room.id);

    // A thread shows its room as open only when it was opened from that
    // room's screen, right below it.
    final below = _claims.length > 1 ? _claims[_claims.length - 2] : null;
    final openedFromRoom = below != null &&
        below.threadId == null &&
        below.room.id == target.room.id;
    return OpenChat(
      roomId: openedFromRoom ? target.room.id : null,
      threadId: threadId,
    );
  }

  /// Ensure the socket is connected using the current token without
  /// joining any specific chat room. Used for per-user channels such
  /// as dashboard updates. Returns once connected or once the attempt has
  /// failed, and right away in the background, where the socket connects
  /// on the return; listeners can be registered either way and survive
  /// reconnects.
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
    if (!_inForeground) return;
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
  /// Nothing connects in the background.
  Future<void> _ensureConnected() {
    if (!_inForeground) {
      return Future.error(StateError('App in the background'));
    }
    // Single-flight: callers share one connect attempt.
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
      _returnConnectFailed();
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

  /// Sends a message to [room] and waits for the server to confirm it was
  /// stored, so the caller can keep the draft when it wasn't.
  ///
  /// The message names its room, and it is never sent while the socket is
  /// in another room. If [room] is the chat on top but isn't joined (yet),
  /// or the server says the socket isn't in it, the send waits up to 5 s for
  /// the room to be joined again and tries once more.
  Future<SendMessageResult> sendMessage(
    String text, {
    required Room room,
    String? parentMessageId,
  }) async {
    final result = await _sendOnce(text, room, parentMessageId);
    final error = result.error;
    if (error == null ||
        !isNotInRoomError(error) ||
        _target?.room.id != room.id) {
      return result;
    }

    final joinError = await _waitForRejoin(room)
        .timeout(_rejoinTimeout, onTimeout: () => error);
    if (joinError != null) {
      return SendMessageResult.failed(joinError);
    }
    return _sendOnce(text, room, parentMessageId);
  }

  Future<SendMessageResult> _sendOnce(
    String text,
    Room room,
    String? parentMessageId,
  ) {
    final socket = _socket;
    if (socket == null || socket.connected != true) {
      return Future.value(const SendMessageResult.failed(_notConnectedError));
    }
    if (_joinedRoomId != room.id) {
      // The socket is in another room, or in none yet: never post there.
      return Future.value(const SendMessageResult.failed(SocketErrorData(
        code: notInRoomCode,
        message: _notInRoomMessage,
      )));
    }

    final data = <String, dynamic>{'text': text, 'roomId': room.id};
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

  /// Registers [callback] for `new_notification`. Returns the handler to pass
  /// to [removeListener].
  dynamic onNewNotification(Function(Map<String, dynamic>) callback) {
    if (kDebugMode) {
      print(
          '📡 SocketService: Registering onNewNotification handler (socket connected: ${_socket?.connected})');
    }
    final handler = addListener('new_notification', (data) {
      if (kDebugMode) {
        print(
            '📡 SocketService: onNewNotification handler called with data: $data');
      }
      callback(data);
    });
    if (kDebugMode) {
      print('✅ SocketService: onNewNotification handler registered');
    }
    return handler;
  }

  /// Like [onNewNotification], with the payload parsed; payloads that can't
  /// be parsed are skipped. Returns the handler to pass to [removeListener].
  dynamic onNewNotificationEntity(
    Function(Notification notification) callback,
  ) {
    return onNewNotification((data) {
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
