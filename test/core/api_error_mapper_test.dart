import 'package:bleya/core/errors/api_error_mapper.dart';
import 'package:bleya/utils/app_errors.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _response(int statusCode, Object? data) {
  final options = RequestOptions(path: '/users/me');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: options,
      statusCode: statusCode,
      data: data,
    ),
  );
}

void main() {
  test('keeps the server message when details is not a map', () {
    final error = ApiErrorMapper.mapDioError(_response(400, {
      'error': {
        'code': 'VALIDATION_ERROR',
        'message': 'Bio is too long.',
        'details': ['bio'],
      },
    }));

    expect(error, isA<BadRequestError>());
    expect(error.getUserMessage(), 'Bio is too long.');
    expect(error.details, isNull);
  });

  test('passes map details through', () {
    final error = ApiErrorMapper.mapDioError(_response(400, {
      'error': {
        'message': 'Invalid input.',
        'details': {'field': 'bio'},
      },
    }));

    expect(error.details, {'field': 'bio'});
  });

  test('ignores a message that is not a string', () {
    final error = ApiErrorMapper.mapDioError(_response(500, {
      'error': {'message': 42},
    }));

    expect(error, isA<ServerError>());
    expect(error.message, 'Server error');
  });
}
