import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'auth_providers.dart';
import '../services/socket_service.dart';

class Room {
  final String id;
  final String name;

  Room({required this.id, required this.name});

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }
}

class Message {
  final String id;
  final String roomId;
  final String userId;
  final String phoneNumber;
  final String text;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.phoneNumber,
    required this.text,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    // Handle createdAt which might be a string or already a DateTime
    DateTime createdAt;
    if (json['createdAt'] is String) {
      createdAt = DateTime.parse(json['createdAt'] as String);
    } else {
      createdAt = DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int);
    }

    return Message(
      id: json['id'] as String,
      roomId: json['roomId'] as String,
      userId: json['userId'] as String,
      phoneNumber: json['phoneNumber'] as String,
      text: json['text'] as String,
      createdAt: createdAt,
    );
  }
}

// Provider to fetch available rooms
final availableRoomsProvider = FutureProvider<List<Room>>((ref) async {
  try {
    final dio = ref.read(dioProvider);
    final token = ref.read(tokenProvider);

    print('Fetching rooms from: ${dio.options.baseUrl}/rooms');
    print('Token available: ${token != null && token.isNotEmpty}');
    if (token != null && token.isNotEmpty) {
      print('Token preview: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
    }

    // Let the request go through - interceptor will handle token and 401
    final response = await dio.get(
      '/rooms',
      options: Options(
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        // Token will be added by interceptor if available
      ),
    );

    print('Rooms response status: ${response.statusCode}');
    print('Rooms response data: ${response.data}');

    if (response.data is! List) {
      throw Exception('Invalid response format: expected List');
    }

    final List<dynamic> roomsJson = response.data;
    return roomsJson.map((json) => Room.fromJson(json)).toList();
  } catch (e, stack) {
    print('Error in availableRoomsProvider: $e');
    print('Stack: $stack');
    if (e is DioException) {
      print(
          'DioException details: ${e.response?.statusCode} - ${e.response?.data}');
      print('Request path: ${e.requestOptions.path}');
      print('Request headers: ${e.requestOptions.headers}');
    }
    rethrow;
  }
});

// Provider to track joined rooms (stored in memory for now)
final joinedRoomsProvider = StateProvider<List<Room>>((ref) => []);

// Provider for current room messages
final roomMessagesProvider =
    StateProvider.family<List<Message>, String>((ref, roomId) => []);

// ChatRoomController manages socket listeners and room operations
class ChatRoomController extends StateNotifier<AsyncValue<void>> {
  final Ref ref;
  final String roomId;
  final SocketService socketService;
  bool _isInitialized = false;

  ChatRoomController(this.ref, this.roomId, this.socketService)
      : super(const AsyncValue.data(null)) {
    _initialize();
  }

  void _initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    _setupSocketListeners();
    _joinRoom();
  }

  void _setupSocketListeners() {
    socketService.onRoomJoined((data) {
      final messages =
          (data['messages'] as List).map((m) => Message.fromJson(m)).toList();
      ref.read(roomMessagesProvider(roomId).notifier).state = messages;
    });

    socketService.onNewMessage((data) {
      final message = Message.fromJson(data);
      if (message.roomId == roomId) {
        final currentMessages = ref.read(roomMessagesProvider(roomId));
        ref.read(roomMessagesProvider(roomId).notifier).state = [
          ...currentMessages,
          message,
        ];
      }
    });

    socketService.onError((data) {
      final errorMsg = data['message'] ?? 'An error occurred';
      print('Socket error: $errorMsg');

      // If "Not in a room" error, try to rejoin
      if (errorMsg.contains('Not in a room')) {
        print('Attempting to rejoin room...');
        Future.delayed(const Duration(milliseconds: 500), () {
          _joinRoom();
        });
      }
    });
  }

  void _joinRoom() {
    socketService.joinRoom(roomId);
  }

  void sendMessage(String text) {
    if (text.trim().isEmpty) return;

    final socket = socketService.socket;
    if (socket == null || !socket.connected) {
      print('Not connected. Cannot send message.');
      return;
    }

    socketService.sendMessage(text);
  }

  void dispose() {
    socketService.off('room_joined');
    socketService.off('new_message');
    socketService.off('error');
    socketService.leaveRoom();
    super.dispose();
  }
}

// Provider for ChatRoomController (family provider for each room)
final chatRoomControllerProvider =
    StateNotifierProvider.family<ChatRoomController, AsyncValue<void>, String>(
  (ref, roomId) {
    final socketService = ref.read(socketServiceProvider);
    final controller = ChatRoomController(ref, roomId, socketService);
    ref.onDispose(() => controller.dispose());
    return controller;
  },
);
