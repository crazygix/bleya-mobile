import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../use_cases/auth/request_code_use_case.dart';
import '../use_cases/auth/resend_code_use_case.dart';
import '../use_cases/auth/verify_code_use_case.dart';
import '../use_cases/auth/check_username_use_case.dart';
import '../use_cases/auth/set_username_use_case.dart';
import '../use_cases/user/get_profile_use_case.dart';
import '../use_cases/user/upload_profile_image_use_case.dart';
import '../use_cases/user/get_user_by_id_use_case.dart';
import '../use_cases/user/update_profile_use_case.dart';
import '../use_cases/room/get_available_rooms_use_case.dart';
import '../use_cases/room/get_joined_rooms_use_case.dart';
import '../use_cases/room/leave_room_use_case.dart';
import '../use_cases/room/create_direct_message_use_case.dart';
import '../use_cases/message/get_thread_use_case.dart';
import '../use_cases/message/get_room_messages_page_use_case.dart';
import 'repository_providers.dart';

final requestCodeUseCaseProvider = Provider<RequestCodeUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return RequestCodeUseCase(repository);
});

final resendCodeUseCaseProvider = Provider<ResendCodeUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return ResendCodeUseCase(repository);
});

final verifyCodeUseCaseProvider = Provider<VerifyCodeUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return VerifyCodeUseCase(repository);
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

final leaveRoomUseCaseProvider = Provider<LeaveRoomUseCase>((ref) {
  final repository = ref.watch(roomRepositoryProvider);
  return LeaveRoomUseCase(repository);
});

final createDirectMessageUseCaseProvider =
    Provider<CreateDirectMessageUseCase>((ref) {
  final repository = ref.watch(roomRepositoryProvider);
  return CreateDirectMessageUseCase(repository);
});

final getThreadUseCaseProvider = Provider<GetThreadUseCase>((ref) {
  final repository = ref.watch(messageRepositoryProvider);
  return GetThreadUseCase(repository);
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
