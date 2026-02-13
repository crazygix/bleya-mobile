import 'package:geolocator/geolocator.dart';

abstract class LocationRepository {
  /// Checks if location services are enabled.
  Future<bool> isLocationServiceEnabled();

  /// Checks the current permission status.
  Future<LocationPermission> checkPermission();

  /// Requests location permission.
  Future<LocationPermission> requestPermission();

  /// Gets the current position.
  /// Throws exception if services are disabled or permissions are denied.
  Future<Position> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration? timeLimit,
  });

  /// Opens the app settings.
  Future<bool> openAppSettings();

  /// Opens the location settings.
  Future<bool> openLocationSettings();
}
