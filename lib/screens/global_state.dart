// global_state.dart
// This centralizes the patient data so all screens share the exact same list.

// Master list for all patients
List<Map<String, dynamic>> globalPatients = [];

// Master list to track completed Ronda shifts
List<Map<String, dynamic>> globalRondas = [];