import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/user_repository.dart';
import '../domain/repositories/room_repository.dart';
import '../domain/repositories/message_repository.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../data/repositories/user_repository_impl.dart';
import '../data/repositories/room_repository_impl.dart';
import '../data/repositories/message_repository_impl.dart';
import 'auth_providers.dart';

/// Wire domain interfaces to data implementations
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final storage = ref.watch(secureStorageProvider);
  return AuthRepositoryImpl(dio, storage);
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return UserRepositoryImpl(dio);
});

final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return RoomRepositoryImpl(dio);
});

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return MessageRepositoryImpl(dio);
});
