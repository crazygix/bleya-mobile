import 'package:flutter/foundation.dart';
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
  final String username;
  final String text;
  final DateTime createdAt;
  final String? parentMessageId;
  final int replyCount;

  Message({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.username,
    required this.text,
    required this.createdAt,
    this.parentMessageId,
    this.replyCount = 0,
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
      username: json['username'] as String? ?? '',
      text: json['text'] as String,
      createdAt: createdAt,
      parentMessageId: json['parentMessageId'] as String?,
      replyCount: json['replyCount'] as int? ?? 0,
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

    if (kDebugMode) {
      print('Fetching rooms from: ${dio.options.baseUrl}/rooms');
      print('Token available: ${token != null && token.isNotEmpty}');
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

    if (kDebugMode) {
      print('Rooms response status: ${response.statusCode}');
    }

    if (response.data is! List) {
      throw Exception('Invalid response format: expected List');
    }

    final List<dynamic> roomsJson = response.data;
    return roomsJson.map((json) => Room.fromJson(json)).toList();
  } catch (e, stack) {
    if (kDebugMode) {
      print('Error in availableRoomsProvider: $e');
      print('Stack: $stack');
      if (e is DioException) {
        print('DioException details: ${e.response?.statusCode}');
        print('Request path: ${e.requestOptions.path}');
        // Don't log response data or headers (may contain sensitive data)
      }
    }
    rethrow;
  }
});

// Provider to fetch joined rooms from backend (single source of truth)
final AutoDisposeFutureProvider<List<Room>> joinedRoomsFutureProvider =
    FutureProvider.autoDispose<List<Room>>((ref) async {
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

    return rooms;
  } catch (e) {
    if (kDebugMode) {
      print('Error fetching joined rooms: $e');
    }
    return [];
  }
});

// Provider for current room messages
final roomMessagesProvider =
    StateProvider.family<List<Message>, String>((ref, roomId) => []);

// ThreadController manages thread state and real-time updates
class ThreadController extends StateNotifier<AsyncValue<Map<String, dynamic>>> {
  final Ref ref;
  final String messageId;
  final SocketService socketService;
  bool _isInitialized = false;
  dynamic _socketHandler;

  ThreadController(this.ref, this.messageId, this.socketService)
      : super(const AsyncValue.loading()) {
    _initialize();
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/messages/$messageId/thread');
      final data = response.data as Map<String, dynamic>;
      final parentMessage = Message.fromJson(data['parentMessage']);
      final initialReplies = (data['replies'] as List)
          .map((json) => Message.fromJson(json))
          .toList();

      state = AsyncValue.data({
        'parentMessage': parentMessage,
        'replies': initialReplies,
      });

      // Listen to socket events for new replies
      _socketHandler = socketService.addListener('new_message', (data) {
        final message = Message.fromJson(data);
        // If this is a reply to our thread's parent message
        if (message.parentMessageId == messageId) {
          final currentState = state.value;
          if (currentState != null) {
            final currentReplies = currentState['replies'] as List<Message>;
            // Check if reply already exists (avoid duplicates)
            if (!currentReplies.any((m) => m.id == message.id)) {
              state = AsyncValue.data({
                'parentMessage': currentState['parentMessage'],
                'replies': [...currentReplies, message],
              });
            }
          }
        }
      });
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  @override
  void dispose() {
    if (_socketHandler != null) {
      socketService.removeListener('new_message', _socketHandler);
    }
    super.dispose();
  }
}

// Provider for thread messages with real-time updates
final threadMessagesProvider = StateNotifierProvider.autoDispose
    .family<ThreadController, AsyncValue<Map<String, dynamic>>, String>(
  (ref, messageId) {
    final socketService = ref.read(socketServiceProvider);
    return ThreadController(ref, messageId, socketService);
  },
);

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
      // Only process if it's for this room
      if (message.roomId == roomId) {
        final currentMessages = ref.read(roomMessagesProvider(roomId));
        
        // If this is a thread reply, update the parent message's replyCount
        if (message.parentMessageId != null) {
          final updatedMessages = currentMessages.map((msg) {
            if (msg.id == message.parentMessageId) {
              // Return updated message with incremented replyCount
              return Message(
                id: msg.id,
                roomId: msg.roomId,
                userId: msg.userId,
                username: msg.username,
                text: msg.text,
                createdAt: msg.createdAt,
                parentMessageId: msg.parentMessageId,
                replyCount: msg.replyCount + 1,
              );
            }
            return msg;
          }).toList();
          
          ref.read(roomMessagesProvider(roomId).notifier).state = updatedMessages;
        } else {
          // Regular top-level message - add it to the list
          ref.read(roomMessagesProvider(roomId).notifier).state = [
            ...currentMessages,
            message,
          ];
        }
      }
    });

    // Register error listener and store handler reference
    _errorHandler = socketService.addListener('error', (data) {
      // Ignore events if this controller has been disposed
      if (_disposed) return;

      final errorMsg = data['message'] ?? 'An error occurred';
      if (kDebugMode) {
        print('Socket error: $errorMsg');
      }

      // If "Not in a room" error, try to rejoin
      if (errorMsg.contains('Not in a room')) {
        if (kDebugMode) {
          print('Attempting to rejoin room...');
        }
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!_disposed) _joinRoom();
        });
      }
    });
  }

  void _joinRoom() {
    // SocketService already tracks the latest token via socketServiceProvider.
    // Joining should always use that latest token.
    socketService.joinRoom(room);
  }

  void sendMessage(String text, {String? parentMessageId}) {
    if (text.trim().isEmpty) return;

    final socket = socketService.socket;
    if (socket == null || !socket.connected) {
      if (kDebugMode) {
        print('Not connected. Cannot send message.');
      }
      return;
    }

    socketService.sendMessage(text, parentMessageId: parentMessageId);
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
    if (kDebugMode) {
      print('Error fetching room members: $e');
    }
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

    // Refresh joined rooms from backend
    ref.invalidate(joinedRoomsFutureProvider);
  } catch (e) {
    if (kDebugMode) {
      print('Error leaving room: $e');
    }
    rethrow;
  }
}

// Function to create or get direct message room with a user
Future<Room> createDirectMessage(WidgetRef ref, String otherUserId) async {
  try {
    final dio = ref.read(dioProvider);
    final response = await dio.post(
      '/rooms/direct/$otherUserId',
      options: Options(
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
      ),
    );

    final roomData = response.data['room'] as Map<String, dynamic>;
    final room = Room.fromJson(roomData);

    // Refresh joined rooms from backend
    ref.invalidate(joinedRoomsFutureProvider);

    return room;
  } catch (e) {
    if (kDebugMode) {
      print('Error creating direct message: $e');
    }
    rethrow;
  }
}
