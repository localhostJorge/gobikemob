import 'dart:async';

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

  /// This phone's Firebase Installation ID (FID): where the server sends to.
  String? _token;
  StreamSubscription<String>? _registeredSub;

  /// Called once from main(). The app still works without Firebase.
  Future<void> init() async {
    try {
      await Firebase.initializeApp();
      _ready = true;
    } catch (e) {
      debugPrint('[push] Firebase not available: $e');
      return;
    }

    FirebaseMessaging.onMessage.listen(_onForeground);
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(m.data));
  }

  /// After login (or a restored session): ask permission and register this
  /// phone with the server so this user's notifications reach it.
  Future<void> registerDevice() async {
    if (!_ready) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(); // Android 13+ asks the user once

      // Fires with the FID once registered, and again if it ever changes.
      _registeredSub ??= messaging.onRegistered.listen((fid) {
        _token = fid;
        _send(fid);
      });
      await messaging.register();
      // Already registered earlier (e.g. another login on this phone): send it again.
      if (_token != null) await _send(_token!);

      // The app was opened by tapping a notification while it was closed.
      final initial = await messaging.getInitialMessage();
      if (initial != null) _open(initial.data);
    } catch (e) {
      debugPrint('[push] could not register this phone: $e');
    }
  }

  /// Before logout, so the next person on this phone doesn't get them.
  Future<void> unregisterDevice() async {
    if (!_ready || _token == null) return;
    await AuthService.instance.callAuthed(
      'DELETE',
      '/mobile/device-token',
      body: {'token': _token},
    );
    try {
      await FirebaseMessaging.instance.unregister();
    } catch (_) {}
    _token = null;
  }

  Future<void> _send(String token) => AuthService.instance.callAuthed(
    'POST',
    '/mobile/device-token',
    body: {'token': token},
  );

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
