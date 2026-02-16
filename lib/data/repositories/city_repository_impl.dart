import 'package:dio/dio.dart';
import '../../core/errors/api_error_mapper.dart';
import '../../domain/entities/city.dart';
import '../../domain/entities/room.dart';
import '../../domain/repositories/city_repository.dart';
import '../dtos/city_dto.dart';
import '../dtos/room_dto.dart';

class CityRepositoryImpl implements CityRepository {
  final Dio _dio;

  CityRepositoryImpl(this._dio);

  @override
  Future<List<City>> getNearby({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _dio.get(
        '/cities/nearby',
        queryParameters: {
          'lat': latitude,
          'lng': longitude,
        },
      );

      return (response.data as List)
          .map((json) => CityDto.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    }
  }

  @override
  Future<Room> joinCity(String cityId) async {
    try {
      final response = await _dio.post('/cities/$cityId/join');
      return RoomDto.fromJson(response.data['room'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    }
  }
}
