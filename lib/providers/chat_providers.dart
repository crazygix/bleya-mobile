import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'auth_providers.dart';
import '../services/socket_service.dart';
import '../models/room.dart';

export '../models/room.dart';

class Message {
  final String id;
  final String roomId;
  final String userId;
  final String phoneNumber;
  final String username;
  final String text;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.phoneNumber,
    required this.username,
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
      username: json['username'] as String? ?? '',
      text: json['text'] as String,
      createdAt: createdAt,
    );
  }
}

class RoomMember {
  final String id;
  final String username;
  final String phoneNumber;
  final String profileImageUrl;

  RoomMember({
    required this.id,
    required this.username,
    required this.phoneNumber,
    required this.profileImageUrl,
  });

  factory RoomMember.fromJson(Map<String, dynamic> json) {
    return RoomMember(
      id: json['id'] as String,
      username: json['username'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String,
      profileImageUrl: json['profileImageUrl'] as String? ?? '',
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
      print(
          'Token preview: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
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

// Provider to fetch joined rooms from backend
final joinedRoomsFutureProvider = FutureProvider<List<Room>>((ref) async {
  try {
    final dio = ref.read(dioProvider);
    final token = ref.read(tokenProvider);

    if (token == null || token.isEmpty) {
      return [];
    }

    final response = await dio.get(
      '/rooms/joined',
      options: Options(
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
      ),
    );

    if (response.data is! List) {
      throw Exception('Invalid response format: expected List');
    }

    final List<dynamic> roomsJson = response.data;
    final rooms = roomsJson.map((json) => Room.fromJson(json)).toList();

    // Save to secure storage for offline access
    final storage = ref.read(secureStorageProvider);
    final roomsJsonString = jsonEncode(roomsJson);
    await storage.write(key: 'joined_rooms', value: roomsJsonString);

    return rooms;
  } catch (e) {
    print('Error fetching joined rooms: $e');
    // Try to load from secure storage as fallback
    try {
      final storage = ref.read(secureStorageProvider);
      final roomsJsonString = await storage.read(key: 'joined_rooms');
      if (roomsJsonString != null) {
        final List<dynamic> roomsJson = jsonDecode(roomsJsonString);
        return roomsJson.map((json) => Room.fromJson(json)).toList();
      }
    } catch (e2) {
      print('Error loading joined rooms from storage: $e2');
    }
    return [];
  }
});

// Provider to track joined rooms (synced with backend)
final joinedRoomsProvider =
    StateNotifierProvider<JoinedRoomsNotifier, List<Room>>((ref) {
  final notifier = JoinedRoomsNotifier(ref);
  // Initialize from storage first for immediate display
  notifier.loadFromStorage();
  // Then sync with backend
  ref.listen(joinedRoomsFutureProvider, (previous, next) {
    next.whenData((rooms) {
      notifier.setRooms(rooms);
    });
  });
  return notifier;
});

// Notifier for managing joined rooms
class JoinedRoomsNotifier extends StateNotifier<List<Room>> {
  final Ref ref;

  JoinedRoomsNotifier(this.ref) : super([]);

  Future<void> loadFromStorage() async {
    try {
      final storage = ref.read(secureStorageProvider);
      final roomsJsonString = await storage.read(key: 'joined_rooms');
      if (roomsJsonString != null) {
        final List<dynamic> roomsJson = jsonDecode(roomsJsonString);
        state = roomsJson.map((json) => Room.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error loading joined rooms from storage: $e');
    }
  }

  void setRooms(List<Room> rooms) {
    state = rooms;
  }

  Future<void> addRoom(Room room) async {
    if (state.any((r) => r.id == room.id)) {
      return; // Already joined
    }

    if (state.length >= 5) {
      throw Exception('You can only join up to 5 rooms at a time');
    }

    state = [...state, room];

    // Save to secure storage
    try {
      final storage = ref.read(secureStorageProvider);
      final roomsJson = state.map((r) => {'id': r.id, 'name': r.name}).toList();
      await storage.write(key: 'joined_rooms', value: jsonEncode(roomsJson));
    } catch (e) {
      print('Error saving joined rooms to storage: $e');
    }
  }

  Future<void> removeRoom(String roomId) async {
    state = state.where((r) => r.id != roomId).toList();

    // Save to secure storage
    try {
      final storage = ref.read(secureStorageProvider);
      final roomsJson = state.map((r) => {'id': r.id, 'name': r.name}).toList();
      await storage.write(key: 'joined_rooms', value: jsonEncode(roomsJson));
    } catch (e) {
      print('Error saving joined rooms to storage: $e');
    }
  }

  Future<void> refresh() async {
    ref.invalidate(joinedRoomsFutureProvider);
  }
}

// Provider for current room messages
final roomMessagesProvider =
    StateProvider.family<List<Message>, String>((ref, roomId) => []);

// ChatRoomController manages socket listeners and room operations
class ChatRoomController extends StateNotifier<AsyncValue<void>> {
  final Ref ref;
  final Room room;
  final SocketService socketService;
  bool _isInitialized = false;
  bool _disposed = false;

  // Store handler references returned from socketService so we can remove only our specific listeners
  dynamic _roomJoinedHandler;
  dynamic _newMessageHandler;
  dynamic _errorHandler;

  ChatRoomController(this.ref, this.room, this.socketService)
      : super(const AsyncValue.data(null)) {
    _initialize();
  }

  String get roomId => room.id;

  void _initialize() {
    if (_isInitialized) {
      // If already initialized, check if we need to rejoin the room
      // This handles the case where we navigate back to a room we were previously in
      _joinRoom();
      return;
    }
    _isInitialized = true;

    _setupSocketListeners();
    _joinRoom();
  }

  void _setupSocketListeners() {
    // Register room_joined listener and store handler reference
    _roomJoinedHandler = socketService.addListener('room_joined', (data) {
      // Ignore events if this controller has been disposed
      if (_disposed) return;

      // Only process if this is for our room
      final roomData = data['room'] as Map<String, dynamic>?;
      final joinedRoomId = roomData?['id'] as String?;
      if (joinedRoomId == roomId) {
        // Confirm room join in socket service
        final joinedRoom = Room.fromJson(roomData!);
        socketService.onRoomJoinedConfirmed(joinedRoom);
        final messages =
            (data['messages'] as List).map((m) => Message.fromJson(m)).toList();
        ref.read(roomMessagesProvider(roomId).notifier).state = messages;
      }
    });

    // Register new_message listener and store handler reference
    _newMessageHandler = socketService.addListener('new_message', (data) {
      // Ignore events if this controller has been disposed
      if (_disposed) return;

      final message = Message.fromJson(data);
      // Only add message if it's for this room
      if (message.roomId == roomId) {
        final currentMessages = ref.read(roomMessagesProvider(roomId));
        ref.read(roomMessagesProvider(roomId).notifier).state = [
          ...currentMessages,
          message,
        ];
      }
    });

    // Register error listener and store handler reference
    _errorHandler = socketService.addListener('error', (data) {
      // Ignore events if this controller has been disposed
      if (_disposed) return;

      final errorMsg = data['message'] ?? 'An error occurred';
      print('Socket error: $errorMsg');

      // If "Not in a room" error, try to rejoin
      if (errorMsg.contains('Not in a room')) {
        print('Attempting to rejoin room...');
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!_disposed) _joinRoom();
        });
      }
    });
  }

  void _joinRoom() {
    socketService.joinRoom(room);
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

  /// Ensure we're in the room - call this when the page becomes visible again
  void ensureInRoom() {
    _joinRoom();
  }

  @override
  void dispose() {
    _disposed = true;

    // Clear messages for this room when leaving
    ref.read(roomMessagesProvider(roomId).notifier).state = [];

    // Remove only our specific socket listeners by passing the handler references
    if (_roomJoinedHandler != null) {
      socketService.removeListener('room_joined', _roomJoinedHandler);
    }
    if (_newMessageHandler != null) {
      socketService.removeListener('new_message', _newMessageHandler);
    }
    if (_errorHandler != null) {
      socketService.removeListener('error', _errorHandler);
    }

    // Note: leaveRoom is called by ChatRoomPage.dispose() to avoid double-leaving
    super.dispose();
  }
}

// Provider for ChatRoomController (family provider for each room)
// Using autoDispose so the controller is disposed when no longer watched
final chatRoomControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatRoomController, AsyncValue<void>, Room>(
  (ref, room) {
    final socketService = ref.read(socketServiceProvider);
    return ChatRoomController(ref, room, socketService);
    // Note: StateNotifierProvider automatically calls dispose() on the notifier
  },
);

// Provider to fetch room members
final roomMembersProvider =
    FutureProvider.family<List<RoomMember>, String>((ref, roomId) async {
  try {
    final dio = ref.read(dioProvider);
    final response = await dio.get(
      '/rooms/$roomId/members',
      options: Options(
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
      ),
    );

    if (response.data is! List) {
      throw Exception('Invalid response format: expected List');
    }

    final List<dynamic> membersJson = response.data;
    return membersJson.map((json) => RoomMember.fromJson(json)).toList();
  } catch (e) {
    print('Error fetching room members: $e');
    rethrow;
  }
});

// Function to leave a room
Future<void> leaveRoom(WidgetRef ref, String roomId) async {
  try {
    final dio = ref.read(dioProvider);
    await dio.post(
      '/rooms/$roomId/leave',
      options: Options(
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
      ),
    );

    // Remove from local state
    final joinedRoomsNotifier = ref.read(joinedRoomsProvider.notifier);
    await joinedRoomsNotifier.removeRoom(roomId);

    // Refresh joined rooms
    await joinedRoomsNotifier.refresh();
  } catch (e) {
    print('Error leaving room: $e');
    rethrow;
  }
}
