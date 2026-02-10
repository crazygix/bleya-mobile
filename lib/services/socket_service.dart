import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/environment.dart';
import '../domain/entities/room.dart';

class SocketService {
  io.Socket? _socket;
  Room? _currentRoom;
  String? _currentToken;
  bool _isReconnecting = false;
  bool _authRefreshInFlight = false;
  Room? _desiredRoom;

  /// Single-flight connection attempt to prevent overlapping connect/reconnect calls.
  Future<void>? _connecting;

  /// Optional callback invoked when an authentication error is detected
  /// on the socket connection.
  ///
  /// Should refresh the token (and typically update token provider) and return
  /// the fresh access token, or null if refresh failed.
  Future<String?> Function()? refreshToken;

  io.Socket? get socket => _socket;

  void setToken(String? token) {
    _currentToken = (token != null && token.isNotEmpty) ? token : null;
    // If token is cleared, disconnect but keep the socket instance (single socket).
    if (_currentToken == null) {
      _isReconnecting = false;
      _socket?.disconnect();
      _currentRoom = null;
      _desiredRoom = null;
      return;
    }
    // Ensure we have a socket instance ready; don't auto-join here.
    _ensureSocketInitialized();
  }

  void _ensureSocketInitialized() {
    if (_socket != null) return;

    final serverUrl = EnvironmentConfig.baseUrl.replaceAll('/api', '');

    _socket = io.io(
      serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          // We'll update auth/headers right before connect.
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      if (kDebugMode) {
        print('Socket connected');
      }
      _isReconnecting = false;
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

    _socket!.onDisconnect((_) {
      if (kDebugMode) {
        print('Socket disconnected');
      }
      if (!_isReconnecting) {
        _currentRoom = null;
      }
    });

    _socket!.onError((error) async {
      if (kDebugMode) {
        print('Socket error: $error');
      }
      await _handleAuthFailureIfNeeded(error);
    });

    _socket!.onConnectError((error) async {
      if (kDebugMode) {
        print('Socket connection error: $error');
      }
      await _handleAuthFailureIfNeeded(error);
    });
  }

  void disconnect() {
    _isReconnecting = false; // Not reconnecting if explicitly disconnecting
    if (_currentRoom != null) {
      leaveRoom();
    }
    _socket?.disconnect();
    _currentRoom = null;
    _desiredRoom = null;
    _currentToken = null;
  }

  Future<void> _handleAuthFailureIfNeeded(dynamic error) async {
    final message = error?.toString() ?? '';
    if (message.contains('Authentication error')) {
      if (kDebugMode) {
        print('Detected socket authentication error');
      }
      // Avoid re-entrant refresh loops.
      if (_authRefreshInFlight) return;
      final refresher = refreshToken;
      if (refresher == null) return;

      _authRefreshInFlight = true;
      try {
        final newToken = await refresher();
        if (newToken != null && newToken.isNotEmpty) {
          // Update local token and reconnect with fresh credentials.
          setToken(newToken);
          await _ensureConnected();
        }
      } finally {
        _authRefreshInFlight = false;
      }
    }
  }

  Future<void> joinRoom(Room room) async {
    _desiredRoom = room;

    if (_currentToken == null || _currentToken!.isEmpty) {
      if (kDebugMode) {
        print('No token available, cannot join room');
      }
      return;
    }

    _ensureSocketInitialized();
    await _ensureConnected();

    // If we are connected, attempt join.
    _doJoinRoom(room);
  }

  /// Ensure the socket is connected using the current token without
  /// joining any specific chat room. Used for per-user channels such
  /// as dashboard updates.
  Future<void> ensureConnectedForUserChannel() async {
    if (_currentToken == null || _currentToken!.isEmpty) {
      if (kDebugMode) {
        print('No token available, cannot connect socket');
      }
      return;
    }
    _ensureSocketInitialized();
    await _ensureConnected();
  }

  Future<void> _ensureConnected() {
    // Single-flight: multiple joinRoom calls should share one connect attempt.
    final existing = _connecting;
    if (existing != null) return existing;

    final completer = Completer<void>();
    _connecting = completer.future;

    () async {
      try {
        if (_socket == null) {
          _ensureSocketInitialized();
        }
        if (_socket == null) {
          throw Exception('Socket not initialized');
        }
        if (_socket!.connected == true) {
          completer.complete();
          return;
        }
        // Update auth/headers right before connect so handshake uses latest token.
        final token = _currentToken;
        if (token == null || token.isEmpty) {
          throw Exception('Missing token');
        }

        try {
          // socket_io_client allows updating option maps dynamically.
          // Ensure we keep a Map for auth and update token in-place.
          final ioManager = _socket!.io;
          final Map<String, dynamic> opts = Map<String, dynamic>.from(
              ioManager.options ?? const <String, dynamic>{});

          final existingAuth = opts['auth'];
          final Map<String, dynamic> authMap = existingAuth is Map
              ? Map<String, dynamic>.from(existingAuth)
              : <String, dynamic>{};
          authMap['token'] = token;
          opts['auth'] = authMap;
          opts['extraHeaders'] = <String, dynamic>{
            'Authorization': 'Bearer $token',
          };
          // Assign back in case the manager stores a different map instance.
          ioManager.options = opts;
        } catch (_) {
          // Best-effort; proceed to connect.
        }

        // Connect and await connect or connect_error.
        _isReconnecting = true;

        late dynamic connectErrorHandler;
        late dynamic connectHandler;

        connectHandler = (_) {
          _socket?.off('connect_error', connectErrorHandler);
          completer.complete();
        };
        connectErrorHandler = (err) async {
          _socket?.off('connect', connectHandler);
          // If auth error, try refresh once then retry connect.
          final msg = err?.toString() ?? '';
          if (msg.contains('Authentication error')) {
            await _handleAuthFailureIfNeeded(err);
          }
          completer.completeError(err ?? Exception('connect_error'));
        };

        _socket!.once('connect', connectHandler);
        _socket!.once('connect_error', connectErrorHandler);
        _socket!.connect();
      } catch (e) {
        completer.completeError(e);
      } finally {
        _connecting = null;
        _isReconnecting = false;
      }
    }();

    return completer.future;
  }

  void _doJoinRoom(Room room) {
    if (_currentRoom?.id == room.id) {
      if (kDebugMode) {
        print('[Room] Already in $room, skipping');
      }
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
  }

  void leaveRoom([String? specificRoomId]) {
    if (specificRoomId != null) {
      if (_currentRoom?.id == specificRoomId) {
        if (kDebugMode) {
          print('[Room] Leaving $_currentRoom');
        }
        _socket?.emit('leave_room');
        _currentRoom = null;
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
      }
    }
  }

  void sendMessage(String text, {String? parentMessageId}) {
    if (_socket?.connected != true) {
      if (kDebugMode) {
        print('Socket not connected, cannot send message');
      }
      return;
    }
    if (_currentRoom == null) {
      if (kDebugMode) {
        print('Not in a room, cannot send message');
      }
      return;
    }
    final data = {'text': text};
    if (parentMessageId != null) {
      data['parentMessageId'] = parentMessageId;
    }
    _socket!.emit('send_message', data);
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

  void onRoomJoined(Function(Map<String, dynamic>) callback) {
    void handler(dynamic data) {
      callback(_normalizePayload(data));
    }

    _socket?.on('room_joined', handler);
    _eventHandlers.putIfAbsent('room_joined', () => []).add(handler);
  }

  void onNewMessage(Function(Map<String, dynamic>) callback) {
    void handler(dynamic data) {
      callback(_normalizePayload(data));
    }

    _socket?.on('new_message', handler);
    _eventHandlers.putIfAbsent('new_message', () => []).add(handler);
  }

  void onError(Function(Map<String, dynamic>) callback) {
    void handler(dynamic data) {
      callback(_normalizePayload(data));
    }

    _socket?.on('error', handler);
    _eventHandlers.putIfAbsent('error', () => []).add(handler);
  }

  void onUserJoined(Function(Map<String, dynamic>) callback) {
    void handler(dynamic data) {
      callback(_normalizePayload(data));
    }

    _socket?.on('user_joined', handler);
    _eventHandlers.putIfAbsent('user_joined', () => []).add(handler);
  }

  void onUserLeft(Function(Map<String, dynamic>) callback) {
    void handler(dynamic data) {
      callback(_normalizePayload(data));
    }

    _socket?.on('user_left', handler);
    _eventHandlers.putIfAbsent('user_left', () => []).add(handler);
  }

  /// Remove a specific callback listener for an event.
  /// Returns the handler that was registered, which should be stored and passed back to removeListener.
  dynamic addListener(String event, Function(Map<String, dynamic>) callback) {
    void handler(dynamic data) {
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

  /// Remove all listeners for an event (use with caution).
  void off(String event) {
    _socket?.off(event);
    _eventHandlers[event]?.clear();
  }
}
