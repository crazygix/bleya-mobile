import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/environment.dart';
import '../models/room.dart';

class SocketService {
  io.Socket? _socket;
  Room? _currentRoom;
  String? _currentToken;
  bool _isReconnecting = false;

  /// Optional callback invoked when an authentication error is detected
  /// on the socket connection.
  Future<void> Function()? onAuthError;

  io.Socket? get socket => _socket;

  void connect(String token) {
    // Remember the room we were in (if any) so we can rejoin after reconnect
    final Room? roomToRejoin = _currentRoom;

    // If socket exists with the same token, don't create a new one
    // (it's either connected or in the process of connecting)
    if (_socket != null && _currentToken == token) {
      // If the socket exists but is currently disconnected, explicitly reconnect.
      // Without this, callers may wait forever for a connect event that never happens.
      if (_socket!.connected != true) {
        _socket!.connect();
      }
      return;
    }

    // If we have an existing socket (possibly with a different token),
    // clean it up before establishing a new connection.
    if (_socket != null) {
      // Mark that we're reconnecting so onDisconnect doesn't clear the room
      _isReconnecting = true;
      _socket!.disconnect();
      _socket = null;
      // Don't clear _currentRoom here - we'll restore it after reconnect
      _currentToken = null;
    } else {
      _isReconnecting = false;
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
        print('Socket connected successfully with token');
      }

      // Clear reconnecting flag
      _isReconnecting = false;

      // If we had a room before reconnect, automatically rejoin it
      if (roomToRejoin != null) {
        if (kDebugMode) {
          print('Rejoining room ${roomToRejoin.name} after reconnect...');
        }
        // Small delay to ensure socket is fully authenticated
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_socket?.connected == true) {
            _doJoinRoom(roomToRejoin);
          }
        });
      }
    });

    _socket!.onDisconnect((_) {
      if (kDebugMode) {
        print('Socket disconnected');
      }
      // Only clear current room if we're not in the middle of a reconnect
      if (!_isReconnecting) {
        _currentRoom = null;
      }
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
      // Clear token if connection fails - might be invalid
      if (error?.toString().contains('Authentication error') == true) {
        _currentToken = null;
      }
      await _handleAuthErrorIfNeeded(error);
    });
  }

  void disconnect() {
    _isReconnecting = false; // Not reconnecting if explicitly disconnecting
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

  void joinRoom(Room room, {String? token}) {
    // Always use the provided token if available, otherwise use current token
    final tokenToUse = token ?? _currentToken;

    // If no token available, can't join
    if (tokenToUse == null || tokenToUse.isEmpty) {
      if (kDebugMode) {
        print('No token available, cannot join room');
      }
      return;
    }

    // If socket is null, connect first
    if (_socket == null) {
      if (kDebugMode) {
        print('Socket is null, connecting with token...');
      }
      connect(tokenToUse);
      // Wait for connection before joining room
      _socket?.once('connect', (_) {
        if (kDebugMode) {
          print('Socket connected, joining room...');
        }
        // Small delay to ensure socket is fully authenticated
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_socket?.connected == true) {
            _doJoinRoom(room);
          }
        });
      });
      return;
    }

    // If token changed, reconnect with new token
    if (tokenToUse != _currentToken) {
      if (kDebugMode) {
        print('Token changed, reconnecting socket with new token...');
      }
      connect(tokenToUse);
      // Wait for connection before joining room
      _socket?.once('connect', (_) {
        if (kDebugMode) {
          print('Socket connected with new token, joining room...');
        }
        // Small delay to ensure socket is fully authenticated
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_socket?.connected == true) {
            _doJoinRoom(room);
          }
        });
      });
      return;
    }

    // Socket exists and token matches
    if (_socket!.connected == true) {
      // Already connected and authenticated, join immediately
      _doJoinRoom(room);
    } else {
      // Socket exists with correct token but not connected yet
      // Wait for it to connect (it's likely in the process of connecting via autoConnect)
      if (kDebugMode) {
        print('Socket not connected yet, waiting for connection...');
      }

      // Ensure a connection attempt is in progress.
      _socket!.connect();

      // Track if we've already handled the join (to avoid double-join from race condition)
      bool joinHandled = false;

      void handleConnect() {
        if (joinHandled) return;
        joinHandled = true;
        if (kDebugMode) {
          print('Socket connected, joining room...');
        }
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_socket?.connected == true) {
            _doJoinRoom(room);
          }
        });
      }

      // Set up one-time handler for connect event
      _socket!.once('connect', (_) => handleConnect());

      // Check again in case it connected between the if check and registering the handler
      if (_socket!.connected == true) {
        handleConnect();
      }
    }
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
