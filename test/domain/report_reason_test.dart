import 'package:bleya/domain/entities/report_reason.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the underage reason uses the backend value', () {
    expect(ReportReason.underage.apiValue, 'underage');
    expect(ReportReason.underage.label, 'Under 15');
  });
}
