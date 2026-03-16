import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/user_repository.dart';
import '../domain/repositories/room_repository.dart';
import '../domain/repositories/message_repository.dart';
import '../domain/repositories/city_repository.dart';
import '../domain/repositories/notification_repository.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../data/repositories/user_repository_impl.dart';
import '../data/repositories/room_repository_impl.dart';
import '../data/repositories/message_repository_impl.dart';
import '../data/repositories/city_repository_impl.dart';
import '../data/repositories/notification_repository_impl.dart';
import '../domain/repositories/location_repository.dart';
import '../data/repositories/location_repository_impl.dart';
import 'auth_providers.dart';

/// Wire domain interfaces to data implementations
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final storage = ref.watch(secureStorageProvider);
  final providerAuthService = ref.watch(providerAuthServiceProvider);
  final passkeyAuthService = ref.watch(passkeyAuthServiceProvider);
  return AuthRepositoryImpl(
    dio,
    storage,
    providerAuthService,
    passkeyAuthService,
  );
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

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepositoryImpl();
});

final cityRepositoryProvider = Provider<CityRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return CityRepositoryImpl(dio);
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return NotificationRepositoryImpl(dio);
});
