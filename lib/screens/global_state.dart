// global_state.dart
// This centralizes the patient data so all screens share the exact same list.

// Master list for all patients
List<Map<String, dynamic>> globalPatients = [];

// NEW: Master list to track completed Ronda shifts
List<Map<String, dynamic>> globalRondas = [];

// NEW: Temporary database for registered accounts
// We start with one default admin account so you can log in immediately
List<Map<String, String>> globalUsers = [
  {
    'name': 'Admin User',
    'email': 'admin@gobike.com',
    'password': 'password123',
  }
];