import '../../domain/entities/analytics_event.dart';
import '../../domain/repositories/analytics_repository.dart';

class RecordAnalyticsEventUseCase {
  final AnalyticsRepository _repository;

  RecordAnalyticsEventUseCase(this._repository);

  void call(AnalyticsEvent event) => _repository.record(event);
}
