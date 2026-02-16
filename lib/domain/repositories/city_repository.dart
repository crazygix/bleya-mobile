import '../entities/city.dart';
import '../entities/room.dart';

abstract class CityRepository {
  /// Fetches nearby cities based on user's location
  Future<List<City>> getNearby({
    required double latitude,
    required double longitude,
  });

  /// Joins a city room (creates if doesn't exist, returns the room)
  Future<Room> joinCity(String cityId);
}
