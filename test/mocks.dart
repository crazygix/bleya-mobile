import 'dart:io';
import 'package:mocktail/mocktail.dart';
import 'package:bleya/domain/repositories/auth_repository.dart';
import 'package:bleya/domain/repositories/room_repository.dart';
import 'package:bleya/domain/repositories/user_repository.dart';
import 'package:bleya/domain/repositories/message_repository.dart';
import 'package:bleya/domain/repositories/city_repository.dart';
import 'package:bleya/domain/repositories/location_repository.dart';
import 'package:bleya/use_cases/auth/request_code_use_case.dart';
import 'package:bleya/use_cases/auth/resend_code_use_case.dart';
import 'package:bleya/use_cases/auth/verify_code_use_case.dart';
import 'package:bleya/use_cases/auth/check_username_use_case.dart';
import 'package:bleya/use_cases/auth/set_username_use_case.dart';
import 'package:bleya/use_cases/user/upload_profile_image_use_case.dart';
import 'package:bleya/use_cases/city/get_nearby_cities_use_case.dart';
import 'package:bleya/use_cases/city/join_city_use_case.dart';
import 'package:bleya/use_cases/location/get_current_location_use_case.dart';

// Repository mocks
class MockAuthRepository extends Mock implements AuthRepository {}

class MockRoomRepository extends Mock implements RoomRepository {}

class MockUserRepository extends Mock implements UserRepository {}

class MockMessageRepository extends Mock implements MessageRepository {}

class MockCityRepository extends Mock implements CityRepository {}

class MockLocationRepository extends Mock implements LocationRepository {}

// Use case mocks (for controller tests)
class MockRequestCodeUseCase extends Mock implements RequestCodeUseCase {}

class MockResendCodeUseCase extends Mock implements ResendCodeUseCase {}

class MockVerifyCodeUseCase extends Mock implements VerifyCodeUseCase {}

class MockCheckUsernameUseCase extends Mock implements CheckUsernameUseCase {}

class MockSetUsernameUseCase extends Mock implements SetUsernameUseCase {}

class MockUploadProfileImageUseCase extends Mock
    implements UploadProfileImageUseCase {}

class MockGetNearbyCitiesUseCase extends Mock
    implements GetNearbyCitiesUseCase {}

class MockJoinCityUseCase extends Mock implements JoinCityUseCase {}

class MockGetCurrentLocationUseCase extends Mock
    implements GetCurrentLocationUseCase {}

// Dart IO mocks
class MockFile extends Mock implements File {}
