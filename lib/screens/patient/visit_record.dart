import 'vital_status.dart';

/// One GoBiker check-up during a ronda.
/// The patient's Medical History is a read-only list of these.
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
  final int? bloodSugar; // mg/dL, null when not tested

  /// GoBiker remarks. Patients can see these.
  final String remarks;

  /// Date and time when the visit record was last updated.
  final DateTime? updatedAt;

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
    this.bloodSugar,
    this.remarks = '',
    this.updatedAt,
  });

  bool get isAdult => Vitals.isAdult(age);

  VitalStatus? get bpStatus => Vitals.bp(systolic, diastolic, age);

  VitalStatus? get pulseStatus => Vitals.pulse(pulse, age);

  VitalStatus? get respirationStatus => Vitals.respiration(respiration, age);

  VitalStatus? get temperatureStatus => Vitals.temperature(temperature, age);

  VitalStatus? get bloodSugarStatus => Vitals.bloodSugar(bloodSugar, age);

  /// One visit from GET /api/resident/visits.
  factory VisitRecord.fromJson(Map<String, dynamic> j) {
    final date =
        DateTime.tryParse('${j['recorded_at'] ?? ''}')?.toLocal() ??
        DateTime.now();
    final updated = DateTime.tryParse('${j['updated_at'] ?? ''}')?.toLocal();
    int asInt(dynamic v) => (v as num?)?.toInt() ?? int.tryParse('$v') ?? 0;
    final gobiker = '${j['gobiker_name'] ?? ''}'.trim();

    return VisitRecord(
      id: '${j['id']}',
      date: date,
      place: '${j['barangay'] ?? ''}'.trim().isEmpty
          ? 'Bugallon'
          : '${j['barangay']}, Bugallon',
      gobikerName: gobiker.isEmpty ? 'GoBiker' : 'GoBiker $gobiker',
      patientName: '${j['name'] ?? ''}',
      address: '${j['address'] ?? ''}',
      contactNumber: '${j['contact'] ?? ''}',
      age: asInt(j['age']),
      systolic: asInt(j['sys']),
      diastolic: asInt(j['dia']),
      pulse: asInt(j['pulse']),
      respiration: asInt(j['resp']),
      temperature: (j['temp'] as num?)?.toDouble() ?? 0,
      bloodSugar: (j['blood_sugar'] as num?)?.toInt(),
      remarks: '${j['remarks'] ?? ''}',
      // Saving a record also sets updated_at; only a later edit counts as an update.
      updatedAt: updated != null && updated.difference(date).inMinutes >= 1
          ? updated
          : null,
    );
  }
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

String monthShort(DateTime d) => _months[d.month - 1].toUpperCase();

String formatTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');

  return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
}
