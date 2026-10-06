import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// What we remember about a ronda that is in progress.
class SavedRonda {
  const SavedRonda({
    required this.startedAt,
    required this.distanceMeters,
    required this.patientsCount,
    this.barangay,
  });

  final DateTime startedAt;
  final double distanceMeters;
  final int patientsCount;
  final String? barangay;

  Map<String, dynamic> toJson() => {
    'startedAt': startedAt.toIso8601String(),
    'distanceMeters': distanceMeters,
    'patientsCount': patientsCount,
    'barangay': barangay,
  };

  factory SavedRonda.fromJson(Map<String, dynamic> j) => SavedRonda(
    startedAt: DateTime.parse(j['startedAt'] as String),
    distanceMeters: (j['distanceMeters'] as num).toDouble(),
    patientsCount: j['patientsCount'] as int,
    barangay: j['barangay'] as String?,
  );
}

/// Saves and loads the ronda on the phone.
class RondaStore {
  static const _kRonda = 'ronda.current';
  static const _kPendingStop = 'ronda.pendingStop';

  static Future<void> save(SavedRonda r) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRonda, jsonEncode(r.toJson()));
  }

  static Future<SavedRonda?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kRonda);
    if (raw == null) return null;
    try {
      return SavedRonda.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRonda);
  }

  /// true = "we still need to tell the server the ronda ended".
  static Future<void> setPendingStop(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value) {
      await prefs.setBool(_kPendingStop, true);
    } else {
      await prefs.remove(_kPendingStop);
    }
  }

  static Future<bool> hasPendingStop() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kPendingStop) ?? false;
  }
}
