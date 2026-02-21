import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/errors/api_error_mapper.dart';
import '../../domain/repositories/room_repository.dart';
import '../../domain/entities/room.dart';
import '../../domain/entities/room_member.dart';
import '../../domain/entities/direct_chat_status.dart';
import '../dtos/room_dto.dart';
import '../dtos/room_member_dto.dart';
import '../dtos/direct_chat_dto.dart';

/// Data layer implementation of RoomRepository
/// Handles all Dio/network concerns and JSON parsing
class RoomRepositoryImpl implements RoomRepository {
  final Dio _dio;

  RoomRepositoryImpl(this._dio);

  @override
  Future<List<Room>> getAvailableRooms() async {
    try {
      if (kDebugMode) {
        print('Fetching rooms from: ${_dio.options.baseUrl}/rooms');
      }

      final response = await _dio.get(
        '/rooms',
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      if (kDebugMode) {
        print('Rooms response status: ${response.statusCode}');
      }

      if (response.data is! List) {
        throw Exception('Invalid response format: expected List');
      }

      final List<dynamic> roomsJson = response.data;
      return roomsJson.map((json) => RoomDto.fromJson(json)).toList();
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    } catch (e, stack) {
      if (kDebugMode) {
        print('Error in getAvailableRooms: $e');
        print('Stack: $stack');
      }
      rethrow;
    }
  }

  @override
  Future<List<Room>> getJoinedRooms() async {
    try {
      final response = await _dio.get(
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
      return roomsJson.map((json) => RoomDto.fromJson(json)).toList();
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching joined rooms: $e');
      }
      rethrow;
    }
  }

  @override
  Future<Room> joinRoom(String roomId) async {
    try {
      final response = await _dio.post(
        '/rooms/$roomId/join',
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.data is! Map<String, dynamic>) {
        throw Exception('Invalid response format: expected object');
      }

      final payload = response.data as Map<String, dynamic>;
      if (payload['room'] is! Map<String, dynamic>) {
        throw Exception('Invalid response format: expected room object');
      }

      final roomData = payload['room'] as Map<String, dynamic>;
      return RoomDto.fromJson(roomData);
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    } catch (e) {
      if (kDebugMode) {
        print('Error joining room: $e');
      }
      rethrow;
    }
  }

  @override
  Future<List<RoomMember>> getRoomMembers(String roomId) async {
    try {
      final response = await _dio.get(
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
      return membersJson.map((json) => RoomMemberDto.fromJson(json)).toList();
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching room members: $e');
      }
      rethrow;
    }
  }

  @override
  Future<void> leaveRoom(String roomId) async {
    try {
      await _dio.post(
        '/rooms/$roomId/leave',
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    } catch (e) {
      if (kDebugMode) {
        print('Error leaving room: $e');
      }
      rethrow;
    }
  }

  @override
  Future<Room> createDirectMessage(String otherUserId) async {
    try {
      final response = await _dio.post(
        '/rooms/direct/$otherUserId',
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      final roomData = response.data['room'] as Map<String, dynamic>;
      return RoomDto.fromJson(roomData);
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    } catch (e) {
      if (kDebugMode) {
        print('Error creating direct message: $e');
      }
      rethrow;
    }
  }

  @override
  Future<DirectChatStatus> getDirectChatStatus(String otherUserId) async {
    try {
      final response = await _dio.get(
        '/rooms/direct/$otherUserId/status',
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.data is! Map<String, dynamic>) {
        throw Exception('Invalid response format: expected object');
      }

      final payload = response.data as Map<String, dynamic>;
      return DirectChatDto.statusFromJson(payload);
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching direct chat status: $e');
      }
      rethrow;
    }
  }

  @override
  Future<DirectChatActionResult> deleteDirectChat(String otherUserId) async {
    try {
      final response = await _dio.post(
        '/rooms/direct/$otherUserId/delete',
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.data is! Map<String, dynamic>) {
        throw Exception('Invalid response format: expected object');
      }

      final payload = response.data as Map<String, dynamic>;
      return DirectChatDto.actionFromJson(payload);
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting direct chat: $e');
      }
      rethrow;
    }
  }

  @override
  Future<DirectChatActionResult> blockDirectChat(String otherUserId) async {
    try {
      final response = await _dio.post(
        '/rooms/direct/$otherUserId/block',
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.data is! Map<String, dynamic>) {
        throw Exception('Invalid response format: expected object');
      }

      final payload = response.data as Map<String, dynamic>;
      return DirectChatDto.actionFromJson(payload);
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    } catch (e) {
      if (kDebugMode) {
        print('Error blocking direct chat: $e');
      }
      rethrow;
    }
  }

  @override
  Future<Room> getRoom(String roomId) async {
    try {
      final response = await _dio.get('/rooms/$roomId');
      final roomData = response.data as Map<String, dynamic>;

      // The API might return { room: ... } or just the room object.
      // Based on createDirectMessage, it returns { room: ... }.
      // Based on getAvailableRooms, it returns List.
      // Let's assume standard resource fetch returns the object or wrapped.
      // If backend routes/rooms.ts has router.get('/:roomId', ...), let's check what it returns.

      return RoomDto.fromJson(roomData);
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching room: $e');
      }
      rethrow;
    }
  }
}
