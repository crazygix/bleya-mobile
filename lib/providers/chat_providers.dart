import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../constants/urls.dart';
import 'auth_providers.dart';

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
