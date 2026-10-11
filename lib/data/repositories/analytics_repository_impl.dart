import 'dart:async';

import 'package:dio/dio.dart';
import '../dtos/analytics_event_dto.dart';
import '../../domain/entities/analytics_event.dart';
import '../../domain/repositories/analytics_repository.dart';

/// Data layer implementation of AnalyticsRepository (POST /analytics/events).
///
/// Events wait in memory for [batchDelay] so they go out together, at most
/// [maxBatch] per request. A batch that fails for a reason that may pass
/// (offline, rate limit, server error) is kept and sent again after
/// [retryDelay], up to [maxRetries] times in a row; a new event starts the
/// sending again. Events still waiting when the app is closed are lost, which
/// is fine for analytics.
class AnalyticsRepositoryImpl implements AnalyticsRepository {
  static const maxBatch = 25;
  static const maxQueued = 100;
  static const maxRetries = 3;

  final Dio _dio;
  final Duration batchDelay;
  final Duration retryDelay;

  final List<AnalyticsEvent> _queue = [];
  Timer? _timer;
  bool _sending = false;
  int _failures = 0;

  AnalyticsRepositoryImpl(
    this._dio, {
    this.batchDelay = const Duration(seconds: 2),
    this.retryDelay = const Duration(seconds: 30),
  });

  @override
  void record(AnalyticsEvent event) {
    _queue.add(event);
    _dropOldestOverLimit();
    _failures = 0;
    _schedule(_queue.length >= maxBatch ? Duration.zero : batchDelay);
  }

  void _dropOldestOverLimit() {
    if (_queue.length > maxQueued) {
      _queue.removeRange(0, _queue.length - maxQueued);
    }
  }

  void _schedule(Duration delay) {
    if (_sending || _timer != null) return;
    _timer = Timer(delay, () {
      _timer = null;
      unawaited(_send());
    });
  }

  Future<void> _send() async {
    if (_sending || _queue.isEmpty) return;
    _sending = true;

    final batch = _queue.take(maxBatch).toList();
    _queue.removeRange(0, batch.length);
    var failed = false;
    try {
      await _dio.post(
        '/analytics/events',
        data: {'events': batch.map(AnalyticsEventDto.toJson).toList()},
      );
      _failures = 0;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      // A request the backend refused as invalid would be refused again.
      if (status == null || status == 429 || status >= 500) {
        _queue.insertAll(0, batch);
        _dropOldestOverLimit();
        failed = true;
        _failures++;
      }
    } catch (_) {
      // Analytics never surfaces errors.
    } finally {
      _sending = false;
    }

    if (_queue.isEmpty) return;
    if (!failed) {
      _schedule(Duration.zero);
    } else if (_failures <= maxRetries) {
      _schedule(retryDelay);
    }
  }
}
