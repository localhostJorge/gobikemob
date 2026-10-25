import 'dart:async';

import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

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

  /// This phone's Firebase Installation ID (FID): where the server sends to.
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
    // Listen from the start: Firebase announces the FID once, often before
    // anyone has logged in. If it ever changes, tell the server.
    FirebaseMessaging.instance.onRegistered.listen((fid) {
      _token = fid;
      if (AuthService.instance.isLoggedIn) _send(fid);
    });
  }

  /// After login (or a restored session): ask permission and register this
  /// phone with the server so this user's notifications reach it.
  Future<void> registerDevice() async {
    if (!_ready) return;
    status.value = const PushStatus.working();
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(); // Android 13+ asks the user once
      await messaging.register();
      // Ask for the ID directly instead of waiting for the one-time event,
      // which may have fired before login.
      final fid = await FirebaseInstallations.instance.getId();
      _token = fid;
      await _send(fid);
    } catch (e) {
      debugPrint('[push] could not register this phone: $e');
      status.value = const PushStatus.failed(
        "Couldn't set up notifications. Check your connection and try again.",
      );
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
    _refresh(message.data['type']);
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

  /// unknown, working, registered or failed.
  final String state;
  final String? message;
}
