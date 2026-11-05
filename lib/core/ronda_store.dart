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

  // ---------- finished rondas ----------

  /// How many finished rondas are kept on the phone for the History screen.
  static const int maxFinished = 200;

  static String _finishedKey(int userId) => 'ronda.finished.$userId';

  /// The finished rondas this GoBiker has on this phone, oldest first. Each is the map the
  /// dashboard and History read: barangay, date, startTime, endTime, endDateTime (a
  /// DateTime), patientsCount and distance (km). The server keeps only when a ronda started
  /// and ended, so these live here, per account.
  static Future<List<Map<String, dynamic>>> loadFinished(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_finishedKey(userId));
    if (raw == null) return [];
    try {
      final out = <Map<String, dynamic>>[];
      for (final item in jsonDecode(raw) as List) {
        final m = Map<String, dynamic>.from(item as Map);
        final ended = DateTime.tryParse('${m['endDateTime']}');
        if (ended == null) continue; // not a ronda we can place in time
        out.add({
          'barangay': '${m['barangay'] ?? 'Not specified'}',
          'date': '${m['date'] ?? ''}',
          'startTime': '${m['startTime'] ?? ''}',
          'endTime': '${m['endTime'] ?? ''}',
          'endDateTime': ended,
          'patientsCount': (m['patientsCount'] as num?)?.toInt() ?? 0,
          'distance': (m['distance'] as num?)?.toDouble() ?? 0.0,
        });
      }
      return out;
    } catch (_) {
      return []; // damaged: better an empty list than a crash
    }
  }

  /// Adds a finished ronda (same map as [loadFinished] returns), keeping the newest
  /// [maxFinished].
  static Future<void> addFinished(
    int userId,
    Map<String, dynamic> ronda,
  ) async {
    final all = await loadFinished(userId)
      ..add(ronda);
    final kept = all.length > maxFinished
        ? all.sublist(all.length - maxFinished)
        : all;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _finishedKey(userId),
      jsonEncode([
        for (final r in kept)
          {
            ...r,
            'endDateTime': (r['endDateTime'] as DateTime).toIso8601String(),
          },
      ]),
    );
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
