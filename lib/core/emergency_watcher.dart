import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

/// Where the GoBiker's emergency stands.
enum EmergencyPhase {
  /// No emergency is open.
  none,

  /// The alert was sent and the admin has not answered yet.
  waiting,

  /// The admin pressed "Responding" on the live map: they have seen the alert
  /// and are handling it (the admin manages from the office; they do not go to the GoBiker).
  responding,

  /// The admin pressed "Resolve". Stays until the GoBiker dismisses it.
  resolved,
}

/// Follows an emergency the GoBiker sent, so the app can tell them when the
/// admin starts responding and when it is resolved.
///
/// While an emergency is open it asks the server every few seconds
/// (`GET /gobiker/emergency`). The state is kept on the phone, so a response
/// that arrives while the app was closed is still announced on the next start.
class EmergencyWatcher extends ChangeNotifier {
  EmergencyWatcher._();
  static final EmergencyWatcher instance = EmergencyWatcher._();

  static const _prefsKey = 'emergency_phase';
  static const Duration _interval = Duration(seconds: 8);

  EmergencyPhase _phase = EmergencyPhase.none;
  Timer? _timer;
  bool _checking = false;
  bool _loaded = false;

  /// Called once for every change the GoBiker must be told about
  /// (responding, resolved). The app shows a dialog; tests record it.
  void Function(EmergencyPhase phase)? onAnnounce;

  EmergencyPhase get phase => _phase;

  /// An emergency that still needs the admin: sent or being answered.
  bool get isOpen =>
      _phase == EmergencyPhase.waiting || _phase == EmergencyPhase.responding;

  /// Reads what was open before the app closed and carries on watching it.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      _phase = EmergencyPhase.values.firstWhere(
        (p) => p.name == saved && p != EmergencyPhase.none,
        orElse: () => EmergencyPhase.none,
      );
    } catch (e) {
      debugPrint('emergency watcher: could not read saved state: $e');
    }
    notifyListeners();
    if (isOpen) {
      _startTimer();
      await check();
    }
  }

  /// The emergency alert reached the server.
  Future<void> markSent() async {
    _phase = EmergencyPhase.waiting;
    await _save();
    _startTimer();
    notifyListeners();
  }

  /// Asks the server where the emergency stands. Failures are ignored.
  Future<void> check() async {
    if (_checking) return;
    _checking = true;
    try {
      final res = await AuthService.instance.callAuthed(
        'GET',
        '/gobiker/emergency',
      );
      if (!res.ok) return;
      applyServerStatus(res.body['status']?.toString());
    } finally {
      _checking = false;
    }
  }

  /// Applies what the server says: 'emergency', 'responding' or null (none open).
  @visibleForTesting
  void applyServerStatus(String? status) {
    switch (status) {
      case 'responding':
        if (_phase != EmergencyPhase.responding) {
          _setPhase(EmergencyPhase.responding, announce: true);
        }
      case 'emergency':
        // Open on the server but not known here (e.g. sent from another phone).
        if (_phase == EmergencyPhase.none ||
            _phase == EmergencyPhase.resolved) {
          _setPhase(EmergencyPhase.waiting);
        }
      default:
        // Nothing open any more: an emergency we were following was resolved.
        if (isOpen) _setPhase(EmergencyPhase.resolved, announce: true);
    }
  }

  /// The GoBiker closed the "resolved" notice.
  Future<void> dismissResolved() async {
    if (_phase != EmergencyPhase.resolved) return;
    _phase = EmergencyPhase.none;
    await _save();
    notifyListeners();
  }

  /// Forget everything (signing out).
  Future<void> reset() async {
    _timer?.cancel();
    _timer = null;
    _phase = EmergencyPhase.none;
    _loaded = false;
    await _save();
    notifyListeners();
  }

  void _setPhase(EmergencyPhase next, {bool announce = false}) {
    _phase = next;
    if (!isOpen) _stopTimer();
    _save();
    notifyListeners();
    if (announce) onAnnounce?.call(next);
  }

  void _startTimer() {
    _timer ??= Timer.periodic(_interval, (_) {
      if (isOpen) {
        check();
      } else {
        _stopTimer();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_phase == EmergencyPhase.none) {
        await prefs.remove(_prefsKey);
      } else {
        await prefs.setString(_prefsKey, _phase.name);
      }
    } catch (e) {
      debugPrint('emergency watcher: could not save state: $e');
    }
  }
}
