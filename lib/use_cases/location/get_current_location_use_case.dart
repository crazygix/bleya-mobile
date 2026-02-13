import 'package:geolocator/geolocator.dart';
import '../../domain/repositories/location_repository.dart';
import '../../utils/app_errors.dart';

class GetCurrentLocationUseCase {
  final LocationRepository _repository;

  GetCurrentLocationUseCase(this._repository);

  /// Orchestrates the logic to get the current location.
  ///
  /// Checks services and permissions first.
  /// Returns [Position] on success.
  /// Throws [AppLocationServiceDisabledException] if services are disabled.
  /// Throws [AppPermissionDeniedException] if permission is denied.
  /// Throws [AppPermissionDeniedForeverException] if permission is permanently denied.
  Future<Position> call() async {
    final serviceEnabled = await _repository.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const AppLocationServiceDisabledException();
    }

    var permission = await _repository.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _repository.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const AppPermissionDeniedException("Location permission denied");
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const AppPermissionDeniedForeverException(
          "Location permission denied forever");
    }

    return await _repository.getCurrentPosition(
      timeLimit: const Duration(seconds: 15),
    );
  }

  Future<void> openAppSettings() async {
    await _repository.openAppSettings();
  }
}
