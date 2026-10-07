import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth_database.dart';

enum ActivityType { sos, appointment, checkup, checkupUpdated }

/// One line in the patient's History (SOS sent, appointment set, ...).
class ActivityEntry {
  final ActivityType type;
  final String title;
  final String subtitle;
  final DateTime time;

  const ActivityEntry({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'title': title,
        'subtitle': subtitle,
        'time': time.toIso8601String(),
      };

  factory ActivityEntry.fromJson(Map<String, dynamic> j) => ActivityEntry(
        type: ActivityType.values.firstWhere(
          (t) => t.name == j['type'],
          orElse: () => ActivityType.sos,
        ),
        title: j['title'] as String? ?? '',
        subtitle: j['subtitle'] as String? ?? '',
        time: DateTime.tryParse(j['time'] as String? ?? '') ?? DateTime.now(),
      );
}

/// Holds everything the patient side needs to remember on this device:
/// profile info, profile photo, notification preferences and activity log.
/// Data is stored per logged-in user.
class PatientStore extends ChangeNotifier {
  PatientStore._();
  static final PatientStore instance = PatientStore._();

  static const Map<String, bool> toggleDefaults = {
    'sos_updates': true,
    'appointments': true,
    'checkups': true,
    'announcements': false,
    'sound': true,
    'vibration': true,
  };

  SharedPreferences? _prefs;
  int _uid = 0;
  final Map<String, bool> _toggles = {};

  String? fullName;
  String? email;
  String? mobile;
  String? barangay;
  String? photoPath;
  int sosHoldSeconds = 2;
  List<ActivityEntry> activities = [];

  bool toggle(String key) => _toggles[key] ?? toggleDefaults[key] ?? false;

  String _k(String name) => 'u${_uid}_$name';

  Future<SharedPreferences> _p() async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Call after login (the dashboard does this in initState).
  Future<void> load() async {
    final p = await _p();
    _uid = AuthDatabase.instance.currentUserId ?? 0;
    await _readProfile();

    final photo = p.getString(_k('photo'));
    photoPath = (photo != null && File(photo).existsSync()) ? photo : null;
    sosHoldSeconds = p.getInt(_k('sos_hold')) ?? 2;
    for (final e in toggleDefaults.entries) {
      _toggles[e.key] = p.getBool(_k('t_${e.key}')) ?? e.value;
    }
    activities = (p.getStringList(_k('activity')) ?? const <String>[])
        .map((s) => ActivityEntry.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    notifyListeners();
  }

  Future<void> _readProfile() async {
    final row = await AuthDatabase.instance.currentUserRow();
    if (row == null) return;
    fullName = row['full_name'] as String?;
    email = row['email'] as String?;
    mobile = row['mobile'] as String?;
    barangay = row['barangay'] as String?;
  }

  Future<void> refreshProfile() async {
    await _readProfile();
    notifyListeners();
  }

  // ---------- settings ----------

  Future<void> setToggle(String key, bool value) async {
    final p = await _p();
    _toggles[key] = value;
    await p.setBool(_k('t_$key'), value);
    notifyListeners();
  }

  Future<void> setSosHold(int seconds) async {
    final p = await _p();
    sosHoldSeconds = seconds;
    await p.setInt(_k('sos_hold'), seconds);
    notifyListeners();
  }

  // ---------- profile photo ----------

  Future<void> setPhoto(String sourcePath) async {
    final p = await _p();
    final dir = await getApplicationDocumentsDirectory();
    // New file name each time so Flutter doesn't show a cached old image.
    final dest =
        '${dir.path}/profile_${_uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(sourcePath).copy(dest);

    final old = photoPath;
    photoPath = dest;
    await p.setString(_k('photo'), dest);
    if (old != null) {
      try {
        await File(old).delete();
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> removePhoto() async {
    final p = await _p();
    final old = photoPath;
    photoPath = null;
    await p.remove(_k('photo'));
    if (old != null) {
      try {
        await File(old).delete();
      } catch (_) {}
    }
    notifyListeners();
  }

  // ---------- activity log ----------

  Future<void> log(ActivityType type, String title, String subtitle) async {
    final p = await _p();
    activities.insert(
      0,
      ActivityEntry(
        type: type,
        title: title,
        subtitle: subtitle,
        time: DateTime.now(),
      ),
    );
    if (activities.length > 200) activities = activities.sublist(0, 200);
    await p.setStringList(
      _k('activity'),
      activities.map((e) => jsonEncode(e.toJson())).toList(),
    );
    notifyListeners();
  }

  Future<void> clearActivities() async {
    final p = await _p();
    activities = [];
    await p.remove(_k('activity'));
    notifyListeners();
  }

  /// Forget the in-memory session on logout (saved data stays on the device
  /// and returns when the same user logs in again).
  void clearSession() {
    fullName = null;
    email = null;
    mobile = null;
    barangay = null;
    photoPath = null;
    activities = [];
    _uid = 0;
    notifyListeners();
  }
}