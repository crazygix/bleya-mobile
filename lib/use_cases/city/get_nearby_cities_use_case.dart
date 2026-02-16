import '../../domain/entities/city.dart';
import '../../domain/repositories/city_repository.dart';

class GetNearbyCitiesUseCase {
  final CityRepository _cityRepository;

  GetNearbyCitiesUseCase(this._cityRepository);

  Future<List<City>> call({
    required double latitude,
    required double longitude,
  }) async {
    return await _cityRepository.getNearby(
      latitude: latitude,
      longitude: longitude,
    );
  }
}
