import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/global_state.dart';
import 'follow_up.dart';
import 'patient_service.dart';

/// Tracks which admin follow-up decisions the GoBiker has not looked at yet,
/// so the dashboard can say "2 updates from admin".
///
/// A decision counts as new for a person until the GoBiker opens one of that
/// person's records. It becomes new again if the admin changes the decision.
/// What was seen is remembered on the phone.
class FollowUpAlerts extends ChangeNotifier {
  FollowUpAlerts._();
  static final FollowUpAlerts instance = FollowUpAlerts._();

  static const _prefsKey = 'follow_up_seen';

  /// person key -> signature of the decision that was seen.
  Map<String, String> _seen = {};
  final Set<String> _unseen = {};
  bool _loaded = false;
  bool _refreshing = false;

  /// How many people have a decision the GoBiker has not seen yet.
  int get count => _unseen.length;

  /// A decision for this patient the GoBiker has not seen yet.
  bool isNew(Map<String, dynamic> patient) {
    final followUp = FollowUp.from(patient['follow_up']);
    if (followUp == null) return false;
    return _seen[_keyOf(patient)] != followUp.signature;
  }

  /// Reads what was seen before from the phone. Safe to call more than once.
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        _seen = Map<String, String>.from(jsonDecode(raw) as Map);
      }
    } catch (e) {
      debugPrint('follow-up alerts: could not read saved state: $e');
    }
    _loaded = true;
    sync(globalPatients);
  }

  /// Recounts from a list of patient records (as the server sent them).
  void sync(List<Map<String, dynamic>> patients) {
    final before = _unseen.length;
    final next = <String>{
      for (final patient in patients)
        if (isNew(patient)) _keyOf(patient),
    };
    final changed = before != next.length || !_unseen.containsAll(next);
    _unseen
      ..clear()
      ..addAll(next);
    if (changed) notifyListeners();
  }

  /// Downloads the patient list in the background and recounts.
  /// Failures are ignored: the badge simply stays as it was.
  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await load();
      final result = await PatientService.instance.list();
      if (result.ok) {
        globalPatients
          ..clear()
          ..addAll(result.data!);
        sync(globalPatients);
      }
    } finally {
      _refreshing = false;
    }
  }

  /// The GoBiker opened this person's record: their decision is no longer new.
  Future<void> markSeen(Map<String, dynamic> patient) async {
    final followUp = FollowUp.from(patient['follow_up']);
    if (followUp == null) return;
    final key = _keyOf(patient);
    _seen[key] = followUp.signature;
    if (_unseen.remove(key)) notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_seen));
    } catch (e) {
      debugPrint('follow-up alerts: could not save state: $e');
    }
  }

  /// Forget everything (used when signing out, and by tests).
  void reset() {
    _seen = {};
    _unseen.clear();
    _loaded = false;
    notifyListeners();
  }

  String _keyOf(Map<String, dynamic> patient) => FollowUp.personKey(
    '${patient['name'] ?? ''}',
    '${patient['contact'] ?? ''}',
  );
}
