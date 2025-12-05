import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/environment.dart';
import '../models/room.dart';

class SocketService {
  io.Socket? _socket;
  Room? _currentRoom;
  String? _currentToken;

  /// Optional callback invoked when an authentication error is detected
  /// on the socket connection.
  Future<void> Function()? onAuthError;

  io.Socket? get socket => _socket;

  void connect(String token) {
    // If already connected with the same token, nothing to do
    if (_socket?.connected == true && _currentToken == token) {
      return;
    }

    // If we have an existing socket (possibly with a different token),
    // clean it up before establishing a new connection.
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
      _currentRoom = null;
      _currentToken = null;
    }

    // Extract base URL from environment config
    final baseUrl = EnvironmentConfig.baseUrl.replaceAll('/api', '');
    final serverUrl = baseUrl;

    _currentToken = token;

    _socket = io.io(
      serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .enableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      if (kDebugMode) {
        print('Socket connected successfully');
      }
    });

    _socket!.onDisconnect((_) {
      if (kDebugMode) {
        print('Socket disconnected');
      }
      _currentRoom = null;
    });

    _socket!.onError((error) async {
      if (kDebugMode) {
        print('Socket error: $error');
      }
      await _handleAuthErrorIfNeeded(error);
    });

    _socket!.onConnectError((error) async {
      if (kDebugMode) {
        print('Socket connection error: $error');
      }
      await _handleAuthErrorIfNeeded(error);
    });
  }

  void disconnect() {
    if (_currentRoom != null) {
      leaveRoom();
    }
    _socket?.disconnect();
    _socket = null;
    _currentRoom = null;
    _currentToken = null;
  }

  Future<void> _handleAuthErrorIfNeeded(dynamic error) async {
    final message = error?.toString() ?? '';
    if (message.contains('Authentication error')) {
      if (kDebugMode) {
        print('Detected socket authentication error');
      }
      final callback = onAuthError;
      if (callback != null) {
        await callback();
      }
    }
  }

  void joinRoom(Room room) {
    // If socket instance itself is null, we can't join; caller must ensure connect() was called
    if (_socket == null) {
      if (kDebugMode) {
        print(
            'Socket instance is null, cannot join room. Ensure connect(token) is called first.');
      }
      return;
    }

    // If socket exists but is not connected, force a reconnect and wait for connect
    if (_socket!.connected != true) {
      if (kDebugMode) {
        print(
            'Socket not connected, forcing reconnect and waiting for connection...');
      }

      // Avoid stacking multiple connect handlers if joinRoom is called repeatedly
      _socket!
        ..off('connect')
        ..connect()
        ..once('connect', (_) {
          if (kDebugMode) {
            print('Socket connected, joining room...');
          }
          _doJoinRoom(room);
        });
      return;
    }

    _doJoinRoom(room);
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

  void sendMessage(String text) {
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
    _socket!.emit('send_message', {'text': text});
  }

  // Store registered handlers so we can remove specific ones
  final Map<String, List<dynamic>> _eventHandlers = {};

  void onRoomJoined(Function(Map<String, dynamic>) callback) {
    void handler(dynamic data) {
      callback(data as Map<String, dynamic>);
    }

    _socket?.on('room_joined', handler);
    _eventHandlers.putIfAbsent('room_joined', () => []).add(handler);
  }

  void onNewMessage(Function(Map<String, dynamic>) callback) {
    void handler(dynamic data) {
      callback(data as Map<String, dynamic>);
    }

    _socket?.on('new_message', handler);
    _eventHandlers.putIfAbsent('new_message', () => []).add(handler);
  }

  void onError(Function(Map<String, dynamic>) callback) {
    void handler(dynamic data) {
      callback(data as Map<String, dynamic>);
    }

    _socket?.on('error', handler);
    _eventHandlers.putIfAbsent('error', () => []).add(handler);
  }

  void onUserJoined(Function(Map<String, dynamic>) callback) {
    void handler(dynamic data) {
      callback(data as Map<String, dynamic>);
    }

    _socket?.on('user_joined', handler);
    _eventHandlers.putIfAbsent('user_joined', () => []).add(handler);
  }

  void onUserLeft(Function(Map<String, dynamic>) callback) {
    void handler(dynamic data) {
      callback(data as Map<String, dynamic>);
    }

    _socket?.on('user_left', handler);
    _eventHandlers.putIfAbsent('user_left', () => []).add(handler);
  }

  /// Remove a specific callback listener for an event.
  /// Returns the handler that was registered, which should be stored and passed back to removeListener.
  dynamic addListener(String event, Function(Map<String, dynamic>) callback) {
    void handler(dynamic data) {
      callback(data as Map<String, dynamic>);
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
