import 'dart:async';

import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;

import '../screens/appointments_screen.dart';
import '../screens/patient/appointment_screen.dart';
import '../screens/patient/medical_history_screen.dart';
import '../screens/patient/safety_tab.dart';
import '../widgets/app_toast.dart';
import 'app_navigator.dart';
import 'appointments.dart';
import 'auth_service.dart';
import 'emergency_watcher.dart';
import 'resident_sos.dart';
import 'resident_visits.dart';

/// Push notifications (Firebase Cloud Messaging).
///
/// The server sends them when something the user waits for happens: an SOS
/// answered, a home visit accepted, a check-up recorded, a new visit request
/// for a GoBiker. With the app closed, Android shows them; with it open, a
/// short notice appears and the matching screen refreshes. Tapping one opens
/// the matching screen.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool _ready = false;
  bool _openedInitial = false;

  /// Where the server sends to: this phone's FCM registration token (or, if
  /// Firebase can't give one, its installation ID).
  String? _token;

  /// Whether this phone is registered with the server for the signed-in
  /// user, or why not. Shown in the resident's Notification Settings.
  final ValueNotifier<PushStatus> status = ValueNotifier(
    const PushStatus.unknown(),
  );

  /// Called once from main(). The app still works without Firebase.
  Future<void> init() async {
    try {
      await Firebase.initializeApp();
      _ready = true;
    } catch (e) {
      debugPrint('[push] Firebase not available: $e');
      status.value = const PushStatus.failed(
        'Notifications are not available on this phone.',
      );
      return;
    }

    FirebaseMessaging.onMessage.listen(_onForeground);
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(m.data));
    // Firebase can replace the token (e.g. after a reinstall or a long time
    // offline). Tell the server, or notifications stop arriving.
    // ignore: deprecated_member_use
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _token = token;
      if (AuthService.instance.isLoggedIn) _send(token);
    });
  }

  Future<void>? _registering;

  /// After login (or a restored session): ask permission and register this
  /// phone with the server so this user's notifications reach it.
  /// Calls made while one is running wait for that one.
  Future<void> registerDevice() =>
      _registering ??= _register().whenComplete(() => _registering = null);

  Future<void> _register() async {
    if (!_ready) return;
    status.value = const PushStatus.working();
    final messaging = FirebaseMessaging.instance;

    // Android 13+ asks the user once. This throws while another permission
    // prompt (like location, asked when the app opens) is showing; that is
    // no reason to give up, so carry on and check the permission at the end.
    try {
      await messaging.requestPermission();
    } catch (e) {
      debugPrint('[push] permission request skipped: $e');
    }

    try {
      final token = await _withRetry(() => _deviceToken(messaging));
      _token = token;
      await _send(token);
    } catch (e) {
      debugPrint('[push] could not register this phone: $e');
      status.value = PushStatus.failed(
        "Couldn't set up notifications on this phone (${_reason(e)}).",
      );
    }

    if (status.value.state == 'registered') {
      try {
        final settings = await messaging.getNotificationSettings();
        if (settings.authorizationStatus == AuthorizationStatus.denied) {
          status.value = const PushStatus.blocked();
        }
      } catch (_) {}
    }

    // The app was opened by tapping a notification while it was closed.
    if (!_openedInitial) {
      _openedInitial = true;
      try {
        final initial = await FirebaseMessaging.instance.getInitialMessage();
        if (initial != null) _open(initial.data);
      } catch (_) {}
    }
  }

  /// Before logout, so the next person on this phone doesn't get them.
  /// (The phone's Firebase ID stays; it moves to whoever logs in next.)
  Future<void> unregisterDevice() async {
    if (!_ready || _token == null) return;
    await AuthService.instance.callAuthed(
      'DELETE',
      '/mobile/device-token',
      body: {'token': _token},
    );
    status.value = const PushStatus.unknown();
  }

  /// The FCM registration token: Firebase only gives it once this phone is
  /// really registered for messages, so the server never gets an ID Firebase
  /// can't deliver to yet. Falls back to the installation ID if there is none.
  Future<String> _deviceToken(FirebaseMessaging messaging) async {
    try {
      // ignore: deprecated_member_use
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) return token;
    } catch (e) {
      debugPrint('[push] no FCM token, using the installation ID: $e');
    }
    await messaging.register();
    return FirebaseInstallations.instance.getId();
  }

  /// Firebase can fail for a moment right after the app opens, so try
  /// up to three times before reporting a problem.
  Future<T> _withRetry<T>(Future<T> Function() attempt) async {
    const waits = [Duration(seconds: 2), Duration(seconds: 5)];
    for (var i = 0; ; i++) {
      try {
        return await attempt().timeout(const Duration(seconds: 20));
      } catch (e) {
        if (i >= waits.length) rethrow;
        debugPrint('[push] attempt ${i + 1} failed, trying again: $e');
        await Future<void>.delayed(waits[i]);
      }
    }
  }

  /// A short reason a tester can report, e.g. "SERVICE_NOT_AVAILABLE".
  String _reason(Object e) => switch (e) {
    FirebaseException(:final code) => code,
    PlatformException(:final code) => code,
    TimeoutException() => 'timed out',
    _ => e.runtimeType.toString(),
  };

  Future<void> _send(String token) async {
    final res = await AuthService.instance.callAuthed(
      'POST',
      '/mobile/device-token',
      body: {'token': token},
    );
    status.value = res.ok
        ? const PushStatus.registered()
        : PushStatus.failed("Couldn't register this phone: ${res.message}");
  }

  void _onForeground(RemoteMessage message) {
    final type = message.data['type'];
    _refresh(type);
    // SOS changes: the resident home vibrates and shows its own notice.
    if (type == 'sos') return;
    final n = message.notification;
    final context = appNavigatorKey.currentState?.overlay?.context;
    if (n == null || context == null) return;
    AppToast.show(
      context,
      [n.title, n.body].whereType<String>().join(': '),
      duration: const Duration(seconds: 5),
    );
  }

  /// Reloads what the notification is about, so open screens are up to date.
  void _refresh(String? type) {
    switch (type) {
      case 'sos':
        ResidentSos.instance.load();
      case 'appointment':
        ResidentAppointments.instance.load();
      case 'checkup':
        ResidentVisits.instance.load();
      case 'appointment_request' || 'appointment_assigned':
        GobikerAppointments.instance.load();
      case 'emergency':
        if (EmergencyWatcher.instance.isOpen) EmergencyWatcher.instance.check();
    }
  }

  void _open(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    _refresh(type);
    final navigator = appNavigatorKey.currentState;
    if (navigator == null || !AuthService.instance.isLoggedIn) return;

    final Widget? screen = switch (type) {
      'sos' => const _SafetyScreen(),
      'appointment' => const AppointmentScreen(),
      'checkup' => const MedicalHistoryScreen(),
      'appointment_request' ||
      'appointment_assigned' => const AppointmentsScreen(),
      _ => null, // e.g. an emergency: the dashboard already shows it
    };
    if (screen != null) {
      navigator.push(MaterialPageRoute(builder: (_) => screen));
    }
  }
}

/// The resident's Safety tab on its own page (opened from a notification).
class _SafetyScreen extends StatelessWidget {
  const _SafetyScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: const SafeArea(child: SafetyTab(active: true)),
  );
}

/// Whether this phone is set up to receive the signed-in user's notifications.
class PushStatus {
  const PushStatus._(this.state, [this.message]);
  const PushStatus.unknown() : this._('unknown');
  const PushStatus.working() : this._('working');
  const PushStatus.registered() : this._('registered');
  const PushStatus.failed(String message) : this._('failed', message);

  /// Registered, but notifications are turned off for the app in the
  /// phone's settings, so nothing will show.
  const PushStatus.blocked() : this._('blocked');

  /// unknown, working, registered, blocked or failed.
  final String state;
  final String? message;
}
