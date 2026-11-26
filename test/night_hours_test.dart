import 'package:flutter_test/flutter_test.dart';
import 'package:go_bike_app/core/night_hours.dart';

void main() {
  DateTime at(int h, int m) => DateTime(2026, 11, 26, h, m);

  test('night runs from 8 PM to just before 6 AM, across midnight', () {
    expect(isNightHours(at(19, 59)), isFalse);
    expect(isNightHours(at(20, 0)), isTrue);
    expect(isNightHours(at(23, 30)), isTrue);
    expect(isNightHours(at(0, 30)), isTrue);
    expect(isNightHours(at(5, 59)), isTrue);
    expect(isNightHours(at(6, 0)), isFalse);
    expect(isNightHours(at(12, 0)), isFalse);
  });
}
