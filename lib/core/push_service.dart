import 'dart:async';

import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;

import '../screens/announcements_screen.dart';
import '../screens/appointments_screen.dart';
import '../screens/gobiker_messages_screen.dart';
import '../screens/live_map_screen.dart';
import '../screens/patient_management_screen.dart';
import '../screens/patient/appointment_screen.dart';
import '../screens/patient/medical_history_screen.dart';
import '../screens/patient/safety_tab.dart';
import '../screens/patient/visit_request_screen.dart';
import '../widgets/app_toast.dart';
import '../widgets/brand.dart';
import 'announcements.dart';
import 'app_navigator.dart';
import 'appointments.dart';
import 'auth_service.dart';
import 'emergency_watcher.dart';
import 'feedback_prompt.dart';
import 'follow_up_alerts.dart';
import 'gobiker_messages.dart';
import 'live_map.dart';
import 'resident_sos.dart';
import 'resident_visits.dart';
import 'sos_actions.dart';

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

  /// Assignments this GoBiker has already been alerted about, keyed by
  /// [sosAlertKey], so a repeated push can't stack dialogs on top of each
  /// other. Sent to the same SOS again (say, after declining) is a new key,
  /// so it alerts again. Cleared on sign-out.
  final Set<String> _alertedSos = {};
  bool _alerting = false;

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
    // The admin sent this GoBiker to an emergency: its own alert loads the
    // list, so don't also refresh here and race it.
    if (type == 'sos_assigned') {
      _alertSosAssigned(
        int.tryParse('${message.data['id'] ?? ''}'),
        message.data['assigned_at']?.toString(),
      );
      return;
    }
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

  /// One assignment of SOS [id]: its id and when the admin sent this GoBiker
  /// ([assignedAt], ISO, null from older servers). The time is read as a
  /// moment, so the push and the list agree however each one writes it.
  static String sosAlertKey(int id, Object? assignedAt) {
    final at = switch (assignedAt) {
      final DateTime t => t,
      null => null,
      _ => DateTime.tryParse('$assignedAt'),
    };
    return '$id:${at?.toUtc().toIso8601String() ?? assignedAt ?? ''}';
  }

  /// Records that this assignment was alerted. False when it already was.
  @visibleForTesting
  bool alertOnce(int id, Object? assignedAt) =>
      _alertedSos.add(sosAlertKey(id, assignedAt));

  /// Vibrates and pops up the emergency the admin just sent this GoBiker to,
  /// with Accept (opens the map on the resident's exact location) and Decline.
  Future<void> _alertSosAssigned(int? id, String? assignedAt) async {
    if (id == null || _alerting) return;
    if (_alertedSos.contains(sosAlertKey(id, assignedAt))) return;
    _alerting = true;
    try {
      await GobikerSos.instance.load();
      final sos = GobikerSos.instance.open.where((s) => s.id == id).firstOrNull;
      // Already resolved, or not ours after all: nothing to show, and a later
      // push for it may still alert.
      if (sos == null || !sos.isOpen) return;
      alertOnce(id, assignedAt);
      // The list may give the time when the push did not: remember it too, so
      // the missed-assignment check doesn't show it twice.
      alertOnce(id, sos.assignedAt);
      await _showAssigned(sos);
    } finally {
      _alerting = false;
    }
  }

  /// After the list loads (app start, back from the background): alerts for an
  /// SOS the admin sent this GoBiker to in the last 5 minutes that was never
  /// shown, because the app was closed or the push did not arrive.
  Future<void> checkMissedAssignments() async {
    if (_alerting) return;
    _alerting = true;
    try {
      final since = DateTime.now().subtract(const Duration(minutes: 5));
      final missed = GobikerSos.instance.open.where(
        (s) =>
            s.isOpen &&
            s.assignedAt != null &&
            s.assignedAt!.isAfter(since) &&
            !_alertedSos.contains(sosAlertKey(s.id, s.assignedAt)),
      );
      for (final sos in missed.toList()) {
        alertOnce(sos.id, sos.assignedAt);
        await _showAssigned(sos);
      }
    } finally {
      _alerting = false;
    }
  }

  /// Shows the alert until the GoBiker accepts (the map opens on the SOS) or
  /// declines with a reason. Going back from the reason brings the alert back.
  Future<void> _showAssigned(AssignedSos sos) async {
    while (true) {
      final choice = await showSosAssignedAlert(
        residentName: sos.residentName,
        place: sos.place,
      );
      switch (choice) {
        case null:
          return; // no screen to show it on
        case SosAlertChoice.accept:
          appNavigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => LiveMapScreen(focusSosId: sos.id),
            ),
          );
          return;
        case SosAlertChoice.decline:
          // Inside the navigator's overlay, so the toast after it can show.
          final context = appNavigatorKey.currentState?.overlay?.context;
          if (context == null || !context.mounted) return;
          if (await declineAssignedSos(context, sos.id)) return;
      }
    }
  }

  /// Forgets which emergencies were already shown (on sign-out).
  void reset() {
    _alertedSos.clear();
    _alerting = false;
  }

  /// Reloads what the notification is about, so open screens are up to date.
  void _refresh(String? type) {
    switch (type) {
      case 'sos':
        ResidentSos.instance.load();
        FeedbackPrompt.instance.check(); // a GoBiker resolved it: rate them
      case 'appointment':
        ResidentAppointments.instance.load();
      case 'checkup':
        ResidentVisits.instance.load();
        FeedbackPrompt.instance.check(); // rate the check-up
      case 'sos_assigned' || 'sos_cancelled':
        GobikerSos.instance.load();
      case 'appointment_request' || 'appointment_assigned':
        GobikerAppointments.instance.load();
      case 'emergency':
        if (EmergencyWatcher.instance.isOpen) EmergencyWatcher.instance.check();
      case 'announcement':
        Announcements.instance.refresh();
      case 'gobiker_message_reply':
        GobikerMessages.instance.refresh();
      case 'follow_up':
        FollowUpAlerts.instance.refresh();
    }
  }

  void _open(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    _refresh(type);
    final navigator = appNavigatorKey.currentState;
    if (navigator == null || !AuthService.instance.isLoggedIn) return;

    final Widget? screen = switch (type) {
      'sos' => const _SafetyScreen(),
      // The answer to a visit request (accepted, declined, done): that request's details.
      // Without an id (an older server), the request form.
      'appointment' => switch (int.tryParse('${data['id'] ?? ''}')) {
        final id? => VisitRequestScreen(appointmentId: id),
        null => const AppointmentScreen(),
      },
      'checkup' => const MedicalHistoryScreen(),
      'appointment_request' ||
      'appointment_assigned' => const AppointmentsScreen(),
      'announcement' => const AnnouncementsScreen(),
      'gobiker_message_reply' => const GobikerMessagesScreen(),
      'follow_up' => const PatientManagementScreen(),
      'sos_assigned' => LiveMapScreen(
        focusSosId: int.tryParse('${data['id'] ?? ''}'),
      ),
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
    // Opened from a notification: the wordmark says which app this is.
    appBar: AppBar(title: const GoBikeWordmark(fontSize: 20)),
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
