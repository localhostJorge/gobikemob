import 'package:flutter_test/flutter_test.dart';
import 'package:go_bike_app/screens/patient/visit_record.dart';

Map<String, dynamic> _visit([Map<String, dynamic> overrides = const {}]) => {
  'id': 7,
  'recorded_at': '2026-10-03T01:30:00+00:00',
  'updated_at': '2026-10-03T01:30:00+00:00',
  'barangay': 'Poblacion',
  'gobiker_name': 'Maria Santos',
  'name': 'Juan Dela Cruz',
  'address': 'Purok 3',
  'contact': '09123456789',
  'age': 45,
  'sys': 138,
  'dia': 88,
  'pulse': 82,
  'resp': 18,
  'temp': 36.8,
  'blood_sugar': 118,
  'remarks': 'Less salt.',
  ...overrides,
};

void main() {
  test('reads a visit from the API', () {
    final v = VisitRecord.fromJson(_visit());

    expect(v.id, '7');
    expect(v.place, 'Poblacion, Bugallon');
    expect(v.gobikerName, 'GoBiker Maria Santos');
    expect(v.systolic, 138);
    expect(v.temperature, 36.8);
    expect(v.bloodSugar, 118);
    expect(v.remarks, 'Less salt.');
  });

  test('a record saved once is not shown as updated', () {
    expect(VisitRecord.fromJson(_visit()).updatedAt, isNull);
  });

  test('a record edited later is shown as updated', () {
    final v = VisitRecord.fromJson(
      _visit({'updated_at': '2026-10-04T02:30:00+00:00'}),
    );
    expect(v.updatedAt, isNotNull);
  });

  test('missing optional values do not break the screen', () {
    final v = VisitRecord.fromJson(
      _visit({
        'blood_sugar': null,
        'remarks': null,
        'barangay': null,
        'gobiker_name': null,
        'temp': 37,
      }),
    );

    expect(v.bloodSugar, isNull);
    expect(v.remarks, '');
    expect(v.place, 'Bugallon');
    expect(v.gobikerName, 'GoBiker');
    expect(v.temperature, 37.0);
  });
}
