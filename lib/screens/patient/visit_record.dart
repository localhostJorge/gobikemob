import 'dart:math';

import 'vital_status.dart';

/// One GoBiker check-up during a ronda. The patient's Medical History is a
/// read-only list of these.
class VisitRecord {
  final String id;
  final DateTime date;
  final String place; // barangay / ronda location
  final String gobikerName;

  // Patient info as filled in by the GoBiker
  final String patientName;
  final String address;
  final String contactNumber;
  final int age;

  // Vitals
  final int systolic;
  final int diastolic;
  final int pulse;
  final int respiration;
  final double temperature; // °C
  final double heightCm;
  final double weightKg;

  /// GoBiker remarks. Patients can see these.
  final String remarks;

  VisitRecord({
    required this.id,
    required this.date,
    required this.place,
    required this.gobikerName,
    required this.patientName,
    required this.address,
    required this.contactNumber,
    required this.age,
    required this.systolic,
    required this.diastolic,
    required this.pulse,
    required this.respiration,
    required this.temperature,
    required this.heightCm,
    required this.weightKg,
    this.remarks = '',
  });

  bool get isAdult => Vitals.isAdult(age);

  double get bmi => weightKg / pow(heightCm / 100, 2);

  VitalStatus? get bpStatus => Vitals.bp(systolic, diastolic, age);
  VitalStatus? get pulseStatus => Vitals.pulse(pulse, age);
  VitalStatus? get respirationStatus => Vitals.respiration(respiration, age);
  VitalStatus? get temperatureStatus => Vitals.temperature(temperature, age);
  VitalStatus? get bmiStatus => Vitals.bmi(bmi, age);
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

String monthShort(DateTime d) => _months[d.month - 1].toUpperCase();

String formatTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
}

/// TEMPORARY sample data so the screens can be tested.
/// Later, replace this with records fetched from your Laravel API for the
/// logged-in patient only.
final List<VisitRecord> sampleVisits = [
  VisitRecord(
    id: 'v3',
    date: DateTime(2026, 10, 3, 9, 30),
    place: 'Poblacion, Bugallon',
    gobikerName: 'GoBiker Maria Santos',
    patientName: 'Juan Dela Cruz',
    address: 'Purok 3, Poblacion, Bugallon',
    contactNumber: '09123456789',
    age: 45,
    systolic: 138,
    diastolic: 88,
    pulse: 82,
    respiration: 18,
    temperature: 36.8,
    heightCm: 165,
    weightKg: 72,
    remarks: 'Advised to reduce salt intake and recheck BP in one week. '
        'Please visit the barangay health center if headaches continue.',
  ),
  VisitRecord(
    id: 'v2',
    date: DateTime(2026, 8, 15, 14, 10),
    place: 'Poblacion, Bugallon',
    gobikerName: 'GoBiker Pedro Reyes',
    patientName: 'Juan Dela Cruz',
    address: 'Purok 3, Poblacion, Bugallon',
    contactNumber: '09123456789',
    age: 45,
    systolic: 126,
    diastolic: 78,
    pulse: 76,
    respiration: 17,
    temperature: 36.6,
    heightCm: 165,
    weightKg: 71,
    remarks: 'No complaints. Encouraged regular exercise.',
  ),
  VisitRecord(
    id: 'v1',
    date: DateTime(2026, 6, 2, 8, 45),
    place: 'Poblacion, Bugallon',
    gobikerName: 'GoBiker Maria Santos',
    patientName: 'Juan Dela Cruz',
    address: 'Purok 3, Poblacion, Bugallon',
    contactNumber: '09123456789',
    age: 45,
    systolic: 118,
    diastolic: 76,
    pulse: 74,
    respiration: 16,
    temperature: 36.5,
    heightCm: 165,
    weightKg: 70,
  ),
];