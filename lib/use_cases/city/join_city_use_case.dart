import '../../domain/entities/room.dart';
import '../../domain/repositories/city_repository.dart';

class JoinCityUseCase {
  final CityRepository _cityRepository;

  JoinCityUseCase(this._cityRepository);

  Future<Room> call(String cityId) async {
    return await _cityRepository.joinCity(cityId);
  }
}
