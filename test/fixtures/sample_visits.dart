import 'package:go_bike_app/screens/patient/visit_record.dart';

/// Check-ups for widget tests (the app loads real ones from the API).
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
    bloodSugar: 118,
    remarks:
        'Advised to reduce salt intake and recheck BP in one week. '
        'Please visit the barangay health center if headaches continue.',
    updatedAt: DateTime(2026, 10, 4, 10, 30),
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
    bloodSugar: 104,
    remarks: 'No complaints. Encouraged regular exercise.',
    updatedAt: DateTime(2026, 8, 16, 9, 15),
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
    // Not tested on the first visit.
  ),
];
