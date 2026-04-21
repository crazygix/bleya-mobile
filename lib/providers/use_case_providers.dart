import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../use_cases/auth/check_username_use_case.dart';
import '../use_cases/auth/get_auth_security_status_use_case.dart';
import '../use_cases/auth/register_passkey_use_case.dart';
import '../use_cases/auth/set_username_use_case.dart';
import '../use_cases/auth/sign_in_with_apple_use_case.dart';
import '../use_cases/auth/sign_in_with_google_use_case.dart';
import '../use_cases/auth/sign_in_with_passkey_use_case.dart';
import '../use_cases/user/get_profile_use_case.dart';
import '../use_cases/user/get_blocked_users_use_case.dart';
import '../use_cases/user/upload_profile_image_use_case.dart';
import '../use_cases/user/get_user_by_id_use_case.dart';
import '../use_cases/user/update_profile_use_case.dart';
import '../use_cases/room/get_available_rooms_use_case.dart';
import '../use_cases/room/get_joined_rooms_use_case.dart';
import '../use_cases/room/join_room_use_case.dart';
import '../use_cases/room/leave_room_use_case.dart';
import '../use_cases/room/create_direct_message_use_case.dart';
import '../use_cases/room/get_room_members_use_case.dart';
import '../use_cases/room/get_direct_chat_status_use_case.dart';
import '../use_cases/room/delete_direct_chat_use_case.dart';
import '../use_cases/room/block_direct_chat_use_case.dart';
import '../use_cases/room/unblock_direct_chat_use_case.dart';
import '../use_cases/message/get_thread_use_case.dart';
import '../use_cases/message/get_room_messages_page_use_case.dart';
import '../use_cases/notification/get_notification_thread_context_use_case.dart';
import '../use_cases/notification/register_push_token_use_case.dart';
import '../use_cases/notification/unregister_push_token_use_case.dart';
import '../use_cases/location/get_current_location_use_case.dart';
import '../use_cases/city/get_nearby_cities_use_case.dart';
import '../use_cases/city/join_city_use_case.dart';
import '../use_cases/room/get_room_use_case.dart';
import 'repository_providers.dart';

final signInWithGoogleUseCaseProvider =
    Provider<SignInWithGoogleUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return SignInWithGoogleUseCase(repository);
});

final signInWithAppleUseCaseProvider = Provider<SignInWithAppleUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return SignInWithAppleUseCase(repository);
});

final signInWithPasskeyUseCaseProvider =
    Provider<SignInWithPasskeyUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return SignInWithPasskeyUseCase(repository);
});

final getAuthSecurityStatusUseCaseProvider =
    Provider<GetAuthSecurityStatusUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return GetAuthSecurityStatusUseCase(repository);
});

final registerPasskeyUseCaseProvider = Provider<RegisterPasskeyUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return RegisterPasskeyUseCase(repository);
});

final checkUsernameUseCaseProvider = Provider<CheckUsernameUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return CheckUsernameUseCase(repository);
});

final setUsernameUseCaseProvider = Provider<SetUsernameUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return SetUsernameUseCase(repository);
});

final getProfileUseCaseProvider = Provider<GetProfileUseCase>((ref) {
  final repository = ref.watch(userRepositoryProvider);
  return GetProfileUseCase(repository);
});

final getBlockedUsersUseCaseProvider = Provider<GetBlockedUsersUseCase>((ref) {
  final repository = ref.watch(userRepositoryProvider);
  return GetBlockedUsersUseCase(repository);
});

final uploadProfileImageUseCaseProvider =
    Provider<UploadProfileImageUseCase>((ref) {
  final repository = ref.watch(userRepositoryProvider);
  return UploadProfileImageUseCase(repository);
});

final getAvailableRoomsUseCaseProvider =
    Provider<GetAvailableRoomsUseCase>((ref) {
  final repository = ref.watch(roomRepositoryProvider);
  return GetAvailableRoomsUseCase(repository);
});

final getJoinedRoomsUseCaseProvider = Provider<GetJoinedRoomsUseCase>((ref) {
  final repository = ref.watch(roomRepositoryProvider);
  return GetJoinedRoomsUseCase(repository);
});

final joinRoomUseCaseProvider = Provider<JoinRoomUseCase>((ref) {
  final repository = ref.watch(roomRepositoryProvider);
  return JoinRoomUseCase(repository);
});

final getRoomMembersUseCaseProvider = Provider<GetRoomMembersUseCase>((ref) {
  final repository = ref.watch(roomRepositoryProvider);
  return GetRoomMembersUseCase(repository);
});

final getRoomUseCaseProvider = Provider<GetRoomUseCase>((ref) {
  final repository = ref.watch(roomRepositoryProvider);
  return GetRoomUseCase(repository);
});

final leaveRoomUseCaseProvider = Provider<LeaveRoomUseCase>((ref) {
  final repository = ref.watch(roomRepositoryProvider);
  return LeaveRoomUseCase(repository);
});

final createDirectMessageUseCaseProvider =
    Provider<CreateDirectMessageUseCase>((ref) {
  final repository = ref.watch(roomRepositoryProvider);
  return CreateDirectMessageUseCase(repository);
});

final getDirectChatStatusUseCaseProvider =
    Provider<GetDirectChatStatusUseCase>((ref) {
  final repository = ref.watch(roomRepositoryProvider);
  return GetDirectChatStatusUseCase(repository);
});

final deleteDirectChatUseCaseProvider =
    Provider<DeleteDirectChatUseCase>((ref) {
  final repository = ref.watch(roomRepositoryProvider);
  return DeleteDirectChatUseCase(repository);
});

final blockDirectChatUseCaseProvider = Provider<BlockDirectChatUseCase>((ref) {
  final repository = ref.watch(roomRepositoryProvider);
  return BlockDirectChatUseCase(repository);
});

final unblockDirectChatUseCaseProvider =
    Provider<UnblockDirectChatUseCase>((ref) {
  final repository = ref.watch(roomRepositoryProvider);
  return UnblockDirectChatUseCase(repository);
});

final getThreadUseCaseProvider = Provider<GetThreadUseCase>((ref) {
  final repository = ref.watch(messageRepositoryProvider);
  return GetThreadUseCase(repository);
});

final getNotificationThreadContextUseCaseProvider =
    Provider<GetNotificationThreadContextUseCase>((ref) {
  final roomRepository = ref.watch(roomRepositoryProvider);
  final messageRepository = ref.watch(messageRepositoryProvider);
  return GetNotificationThreadContextUseCase(
    roomRepository,
    messageRepository,
  );
});

final registerPushTokenUseCaseProvider =
    Provider<RegisterPushTokenUseCase>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  return RegisterPushTokenUseCase(repository);
});

final unregisterPushTokenUseCaseProvider =
    Provider<UnregisterPushTokenUseCase>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  return UnregisterPushTokenUseCase(repository);
});

final getRoomMessagesPageUseCaseProvider =
    Provider<GetRoomMessagesPageUseCase>((ref) {
  final repository = ref.watch(messageRepositoryProvider);
  return GetRoomMessagesPageUseCase(repository);
});

final markRoomAsReadUseCaseProvider = Provider<MarkRoomAsReadUseCase>((ref) {
  final repository = ref.watch(messageRepositoryProvider);
  return MarkRoomAsReadUseCase(repository);
});

final getUserByIdUseCaseProvider = Provider<GetUserByIdUseCase>((ref) {
  final repository = ref.watch(userRepositoryProvider);
  return GetUserByIdUseCase(repository);
});

final updateProfileUseCaseProvider = Provider<UpdateProfileUseCase>((ref) {
  final repository = ref.watch(userRepositoryProvider);
  return UpdateProfileUseCase(repository);
});

final getCurrentLocationUseCaseProvider =
    Provider<GetCurrentLocationUseCase>((ref) {
  final repository = ref.watch(locationRepositoryProvider);
  return GetCurrentLocationUseCase(repository);
});

final getNearbyCitiesUseCaseProvider = Provider<GetNearbyCitiesUseCase>((ref) {
  final repository = ref.watch(cityRepositoryProvider);
  return GetNearbyCitiesUseCase(repository);
});

final joinCityUseCaseProvider = Provider<JoinCityUseCase>((ref) {
  final repository = ref.watch(cityRepositoryProvider);
  return JoinCityUseCase(repository);
});
