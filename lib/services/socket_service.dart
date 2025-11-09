import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/environment.dart';

class SocketService {
  IO.Socket? _socket;
  String? _currentRoomId;

  IO.Socket? get socket => _socket;

  void connect(String token) {
    if (_socket?.connected == true) {
      return;
    }

    // Extract base URL from environment config
    final baseUrl = EnvironmentConfig.baseUrl.replaceAll('/api', '');
    final serverUrl = baseUrl;

    _socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
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
        _currentRoomId = roomId;
        _socket!.emit('join_room', {'roomId': roomId});
      });
      return;
    }
    print('Joining room: $roomId');
    _currentRoomId = roomId;
    _socket!.emit('join_room', {'roomId': roomId});
  }

  void leaveRoom() {
    if (_currentRoomId != null) {
      _socket?.emit('leave_room');
      _currentRoomId = null;
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

  void onRoomJoined(Function(Map<String, dynamic>) callback) {
    _socket?.on('room_joined', (data) => callback(data));
  }

  void onNewMessage(Function(Map<String, dynamic>) callback) {
    _socket?.on('new_message', (data) => callback(data));
  }

  void onError(Function(Map<String, dynamic>) callback) {
    _socket?.on('error', (data) => callback(data));
  }

  void onUserJoined(Function(Map<String, dynamic>) callback) {
    _socket?.on('user_joined', (data) => callback(data));
  }

  void onUserLeft(Function(Map<String, dynamic>) callback) {
    _socket?.on('user_left', (data) => callback(data));
  }

  void off(String event) {
    _socket?.off(event);
  }
}
