import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/environment.dart';

class SocketService {
  io.Socket? _socket;
  String? _currentRoomId;

  io.Socket? get socket => _socket;

  void connect(String token) {
    if (_socket?.connected == true) {
      return;
    }

    // Extract base URL from environment config
    final baseUrl = EnvironmentConfig.baseUrl.replaceAll('/api', '');
    final serverUrl = baseUrl;

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
      print('Socket connected successfully');
    });

    _socket!.onDisconnect((_) {
      print('Socket disconnected');
      _currentRoomId = null;
    });

    _socket!.onError((error) {
      print('Socket error: $error');
    });

    _socket!.onConnectError((error) {
      print('Socket connection error: $error');
    });
  }

  void disconnect() {
    if (_currentRoomId != null) {
      leaveRoom();
    }
    _socket?.disconnect();
    _socket = null;
  }

  void joinRoom(String roomId) {
    if (_socket?.connected != true) {
      print('Socket not connected, waiting for connection...');
      // Wait for connection if not connected yet
      _socket?.once('connect', (_) {
        print('Socket connected, joining room: $roomId');
        _doJoinRoom(roomId);
      });
      return;
    }
    _doJoinRoom(roomId);
  }

  void _doJoinRoom(String roomId) {
    // If already in this room, no need to do anything
    if (_currentRoomId == roomId) {
      print('Already in room: $roomId, skipping join');
      return;
    }

    // Leave previous room if we're in one
    if (_currentRoomId != null) {
      print('Leaving room: $_currentRoomId');
      _socket?.emit('leave_room');
    }

    // The server automatically leaves the previous room when joining a new one
    // But we also handle it on client side for proper state management
    _currentRoomId = roomId;
    _socket?.emit('join_room', {'roomId': roomId});
    print('Joining room: $roomId');
  }

  /// Called when room_joined event is received to confirm we're in the room
  void onRoomJoinedConfirmed(String roomId) {
    if (_currentRoomId == roomId) {
      print('Confirmed: Successfully joined room: $roomId');
    } else {
      print(
          'Warning: room_joined received for $roomId but currentRoomId is $_currentRoomId');
      _currentRoomId = roomId;
    }
  }

  void leaveRoom([String? specificRoomId]) {
    // If a specific roomId is provided, only leave if we're currently in that room
    // Otherwise, leave whatever room we're currently in
    if (specificRoomId != null) {
      if (_currentRoomId == specificRoomId) {
        print('Leaving room: $specificRoomId');
        _socket?.emit('leave_room');
        _currentRoomId = null;
      } else {
        // If we're not in the specified room, do nothing
        // We're already not in that room, so there's nothing to leave
        print(
            'Not in room $specificRoomId (currently in: $_currentRoomId), nothing to leave');
      }
    } else {
      if (_currentRoomId != null) {
        print('Leaving room: $_currentRoomId');
        _socket?.emit('leave_room');
        _currentRoomId = null;
      }
    }
  }

  void sendMessage(String text) {
    if (_socket?.connected != true) {
      print('Socket not connected, cannot send message');
      return;
    }
    if (_currentRoomId == null) {
      print('Not in a room, cannot send message');
      return;
    }
    print('Sending message to room: $_currentRoomId');
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
