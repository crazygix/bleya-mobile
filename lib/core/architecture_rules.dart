// Bleya Architecture & System Design Rules
//
// This document defines the architectural principles, patterns, and conventions
// that all developers must follow when working on this codebase.
// Similar to theme.dart, this serves as the single source of truth for
// architectural decisions.

// ========================================
// 1. CLEAN ARCHITECTURE PRINCIPLES
// ========================================
//
// DEPENDENCY RULE (CRITICAL):
// - Domain layer MUST NOT import from data/use_cases/controllers/pages
// - Use cases MUST only import from domain/ (interfaces and entities)
// - Data layer MAY import domain/ plus core/ and data/dtos for mapping and error handling
// - Controllers MUST import use_cases/ and domain/entities; shared app-level error types are allowed
// - Pages are presentation layer and MAY import controllers/providers/widgets/constants/utils/services/domain entities
// - Pages MUST NOT import from data/ or use_cases/ directly
//
// LAYER SEPARATION:
// - Domain: Pure business logic, no external dependencies (no Dio, no JSON)
// - Data: All external concerns (Dio, JSON parsing, file I/O)
// - Use Cases: Business logic orchestration
// - Controllers: UI state management
// - Pages: UI rendering only
//
// ========================================
// 2. DATE/TIME HANDLING
// ========================================
//
// RULE: API contracts ALWAYS use timestamps (milliseconds since epoch), NEVER ISO strings
//
// Clarification:
// - This rule is about **API payloads** (backend responses + requests).
// - UI is allowed to format dates as strings for display.
// - Local-only dates (e.g., date/time picker output) can originate as `DateTime`.
// - Domain entities keep `DateTime`; DTOs translate between API timestamps (int) and `DateTime`.
//
// Backend:
// - Always send dates as: date.getTime() (returns int milliseconds)
// - NEVER use: date.toISOString() or date.toString()
//
// Frontend:
// - DTOs MUST expect int timestamps: DateTime.fromMillisecondsSinceEpoch(timestamp)
// - NEVER parse ISO strings from API: DateTime.parse(isoString) is FORBIDDEN for API payloads
// - Domain entities store DateTime objects (not strings, not ints)
//
// Example:
// ```dart
// // ✅ CORRECT
// createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int)
//
// // ❌ WRONG
// createdAt: DateTime.parse(json['createdAt'] as String)
// ```
//
// ========================================
// 3. REPOSITORY PATTERN
// ========================================
//
// RULE: Use cases depend on interfaces, not implementations
//
// RULE (DOMAIN CONTRACTS): Domain repository interfaces MUST NOT return `Map<String, dynamic>`.
// - Use dedicated domain models/entities as return types (small types are fine).
// - `Map<String, dynamic>` is allowed internally in the data layer (e.g., decoding JSON), but must
//   be converted at the repository boundary.
//
// Structure:
// - domain/repositories/*.dart: Abstract interfaces only
// - data/repositories/*_impl.dart: Concrete implementations
// - providers/repository_providers.dart: Wire interfaces to implementations
//
// Example:
// ```dart
// // Domain interface
// abstract class AuthRepository {
//   Future<RequestCodeResult> requestCode({required String phone});
// }
//
// // Domain model (keep it small and explicit)
// class RequestCodeResult {
//   final int codeSentAt; // timestamp (ms since epoch)
//   RequestCodeResult({required this.codeSentAt});
// }
//
// // Data implementation
// class AuthRepositoryImpl implements AuthRepository {
//   // Implementation with Dio
// }
//
// // Use case depends on interface
// class RequestCodeUseCase {
//   final AuthRepository _repository; // Interface, not implementation
// }
// ```
//
// ========================================
// 4. DATA TRANSFER OBJECTS (DTOs)
// ========================================
//
// RULE: DTOs are the API contract boundary.
// - All JSON parsing/serialization happens in data/dtos/
// - Domain entities are pure: no fromJson/toJson, no API field knowledge
// - DTOs enforce API types (e.g., timestamps are `int`), and map into domain types (`DateTime`)
//
// Structure:
// - data/dtos/*_dto.dart: Static methods for JSON parsing
// - Domain entities: Pure objects, no fromJson/toJson
//
// Example:
// ```dart
// // ✅ CORRECT - DTO handles parsing
// class MessageDto {
//   static Message fromJson(Map<String, dynamic> json) {
//     return Message(
//       id: json['id'] as String,
//       createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
//     );
//   }
// }
//
// // ❌ WRONG - Entity should not parse JSON
// class Message {
//   factory Message.fromJson(Map<String, dynamic> json) { ... }
// }
// ```
//
// ========================================
// 5. ERROR HANDLING
// ========================================
//
// RULE: Centralized error mapping in core/errors/
//
// Structure:
// - core/errors/api_error_mapper.dart: Maps DioException to AppError
// - utils/app_errors.dart: Domain error classes
// - All repositories use ApiErrorMapper.mapDioError()
//
// Example:
// ```dart
// try {
//   final response = await _dio.get('/endpoint');
// } on DioException catch (e) {
//   throw ApiErrorMapper.mapDioError(e); // ✅ Centralized
// }
// ```
//
// ========================================
// 6. USE CASES
// ========================================
//
// RULE: One use case = one business operation
//
// Structure:
// - use_cases/{domain}/{action}_use_case.dart
// - Use cases are pure functions (no side effects in use case itself)
// - All side effects (network, storage) happen in repositories
//
// Naming:
// - RequestCodeUseCase (not AuthRequestCodeUseCase)
// - GetProfileUseCase (not UserGetProfileUseCase)
// - CreateDirectMessageUseCase (not RoomCreateDirectMessageUseCase)
//
// ========================================
// 7. CONTROLLERS (State Management)
// ========================================
//
// RULE: Controllers manage UI state, use cases handle business logic
//
// Structure:
// - controllers/*_controller.dart: StateNotifier classes
// - Controllers call use cases, not repositories directly
// - Controllers handle loading/error states for UI
// - Pages only bind UI events/state and render; they MUST NOT contain business decisions
// - Navigation decisions should be driven by controller state (or a dedicated router layer),
//   not ad-hoc logic scattered across pages
//
// Example:
// ```dart
// class AuthController extends StateNotifier<AuthState> {
//   final RequestCodeUseCase _requestCodeUseCase; // ✅ Use case
//
//   Future<void> requestCode(String phone) async {
//     state = state.copyWith(isLoading: true);
//     try {
//       await _requestCodeUseCase(phone: phone);
//     } catch (e) {
//       state = state.copyWith(errorMessage: e.toString());
//     }
//   }
// }
// ```
//
// ========================================
// 8. PROVIDERS (Dependency Injection)
// ========================================
//
// RULE: Providers wire dependencies, never contain business logic
//
// Structure:
// - providers/repository_providers.dart: Wire domain interfaces to data impls
// - providers/use_case_providers.dart: Wire use cases to repositories
// - providers/controller_providers.dart: Wire controllers to use cases
//
// Example:
// ```dart
// final authRepositoryProvider = Provider<AuthRepository>((ref) {
//   final dio = ref.watch(dioProvider);
//   return AuthRepositoryImpl(dio); // Wire interface to implementation
// });
// ```
//
// ========================================
// 9. NAMING CONVENTIONS
// ========================================
//
// Files:
// - Entities: domain/entities/{name}.dart (singular, lowercase)
// - Repositories: domain/repositories/{name}_repository.dart
// - Implementations: data/repositories/{name}_repository_impl.dart
// - DTOs: data/dtos/{name}_dto.dart
// - Use Cases: use_cases/{domain}/{action}_use_case.dart
// - Controllers: controllers/{name}_controller.dart
//
// Classes:
// - Entities: Message, Room, RoomMember (PascalCase, singular)
// - Repositories: AuthRepository (interface), AuthRepositoryImpl (implementation)
// - Use Cases: RequestCodeUseCase (Action + Entity + UseCase)
// - Controllers: AuthController, UsernameController
// - DTOs: MessageDto, RoomDto
//
// ========================================
// 10. FILE ORGANIZATION
// ========================================
//
// lib/
// ├── core/              # Cross-cutting concerns
// │   ├── errors/       # Error mapping
// │   └── architecture_rules.dart  # This file
// ├── domain/            # Business logic (no external deps)
// │   ├── entities/     # Business objects
// │   └── repositories/ # Interfaces
// ├── data/             # External concerns
// │   ├── dtos/        # JSON parsing
// │   └── repositories/ # Implementations
// ├── use_cases/        # Business operations
// ├── controllers/      # UI state
// ├── providers/        # DI wiring
// ├── pages/           # UI
// └── widgets/         # Reusable UI
//
// ========================================
// 11. TESTING GUIDELINES
// ========================================
//
// RULE: Test use cases with mocked repository interfaces
//
// Structure:
// - Mock repository interfaces (not implementations)
// - Test use cases in isolation
// - Test controllers with mocked use cases
//
// Example:
// ```dart
// class MockAuthRepository implements AuthRepository {
//   @override
//   Future<Map<String, dynamic>> requestCode({required String phone}) async {
//     return {'codeSentAt': 1234567890};
//   }
// }
//
// test('RequestCodeUseCase calls repository', () async {
//   final mockRepo = MockAuthRepository();
//   final useCase = RequestCodeUseCase(mockRepo);
//   // Test...
// });
// ```
//
// ========================================
// 12. FORBIDDEN PATTERNS
// ========================================
//
// ❌ NEVER:
// - Import data/ from domain/ or use_cases/
// - Parse JSON in domain entities
// - Use Dio in use cases or domain
// - Use DateTime.parse() for API responses (use timestamps)
// - Create repositories without interfaces
// - Put business logic in controllers (use use cases)
// - Put business logic in pages (use controllers)
// - Return Map<String, dynamic> from domain repositories (use entities)
// - Treat DTOs as domain entities (DTOs are boundary/contract objects only)
// - Mix concerns (e.g., network + business logic in same class)
//
// ========================================
// 13. MIGRATION CHECKLIST
// ========================================
//
// When adding new features:
// 1. ✅ Create domain entity (if new)
// 2. ✅ Create domain repository interface
// 3. ✅ Create data DTO (if entity needs JSON parsing)
// 4. ✅ Create data repository implementation
// 5. ✅ Create use case(s)
// 6. ✅ Wire in providers
// 7. ✅ Create controller (if UI state needed)
// 8. ✅ Create page/widget
//
// ========================================
// 14. CODE REVIEW CHECKLIST
// ========================================
//
// Before submitting PR:
// - [ ] No domain/ imports from data/use_cases/
// - [ ] All dates use timestamps (not ISO strings)
// - [ ] All JSON parsing in DTOs
// - [ ] Use cases depend on interfaces
// - [ ] Controllers use use cases (not repositories)
// - [ ] Error handling uses ApiErrorMapper
// - [ ] Naming follows conventions
// - [ ] Files in correct folders
//
// ========================================
// END OF ARCHITECTURE RULES
// ========================================
