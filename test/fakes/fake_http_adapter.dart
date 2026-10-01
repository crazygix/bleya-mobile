import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Answers one request in place of the server.
typedef FakeHttpHandler = Future<ResponseBody> Function(RequestOptions options);

/// A Dio adapter that answers requests from [handler] instead of the network
/// and records every request it receives.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.handler);

  final FakeHttpHandler handler;
  final List<RequestOptions> requests = [];

  /// How many requests were sent to [path].
  int callsTo(String path) => requests.where((r) => r.path == path).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

/// A Dio with the app's base options that sends every request to [adapter].
Dio fakeDio(FakeHttpAdapter adapter) {
  return Dio(BaseOptions(
    baseUrl: 'https://api.test/v1',
    responseType: ResponseType.json,
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ))
    ..httpClientAdapter = adapter;
}

/// A JSON response with [statusCode] and [body].
ResponseBody jsonResponse(int statusCode, Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

/// The backend's error response: `{error: {code, message}}`.
ResponseBody apiErrorResponse(int statusCode, String code, String message) {
  return jsonResponse(statusCode, {
    'error': {'code': code, 'message': message},
  });
}

/// What Dio reports when the device is offline. Throw it from a handler.
DioException connectionError(RequestOptions options) {
  return DioException(
    requestOptions: options,
    type: DioExceptionType.connectionError,
    error: const SocketException('offline'),
  );
}
