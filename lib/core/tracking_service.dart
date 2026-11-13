import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'auth_service.dart';
import 'distance_tracker.dart';
import 'fix.dart';
import 'ronda_store.dart';

/// Starts/stops a ronda on the server and sends the GoBiker's position while
/// the ronda is active: within 5 seconds of a real move, and every 15 seconds
/// while standing still. A foreground service keeps this running when the
/// screen is locked or the app is in the background.
class TrackingService {
  TrackingService._();
  static final TrackingService instance = TrackingService._();

  static const Duration _interval = Duration(seconds: 5);
  static const Duration _freshFor = Duration(seconds: 20);

  Timer? _timer;
  StreamSubscription<Position>? _stream;
  bool _active = false;
  bool _sending = false;
  final DistanceTracker _distance = DistanceTracker(); // ignores GPS drift
  Fix? _latest; // newest reading from the location stream
  Fix? _sent; // the last reading the server took
  DateTime? _sentAt;
  DateTime? _startedAt;
  String? rondaBarangay; // set by the Active Ronda screen
  int rondaPatients = 0; // set by the Active Ronda screen

  /// Set by the active-ronda screen to react if the server rejects us.
  void Function(String message)? onFatalError;

  bool get isActive => _active;
  bool _sendingEmergency = false;

  /// Sends the emergency alert to the admin. The server marks this
  /// GoBiker as "emergency", which shows red on the admin Live Map.
  Future<({bool ok, int status, String message})> sendEmergencyAlert() async {
    if (_sendingEmergency) {
      return (
        ok: false,
        status: 0,
        message: 'Your alert is already being sent.',
      );
    }
    _sendingEmergency = true;
    try {
      final locError = await prepareEmergencyLocation();
      final fix = _latest;
      if (locError != null || fix == null) {
        return (
          ok: false,
          status: 0,
          message: locError ?? "Couldn't get your location.",
        );
      }

      final res = await AuthService.instance.postAuthed(
        '/gobiker/emergency',
        body: fix.toJson(),
      );
      if (res.ok) {
        return (ok: true, status: res.status, message: '');
      }
      if (res.status == 401) {
        return (
          ok: false,
          status: res.status,
          message: 'Your login expired. Please log in again.',
        );
      }
      return (ok: false, status: res.status, message: res.message);
    } finally {
      _sendingEmergency = false;
    }
  }

  /// Distance during the current (or last) ronda, from GPS.
  double get distanceKm => _distance.meters / 1000;

  /// Returns null on success, otherwise a message to show to the user.
  Future<String?> startRonda() async {
    if (_active) return null;

    final accessError = await _ensureLocationAccess();
    if (accessError != null) return accessError;

    Fix first;
    try {
      first = await _currentFix();
    } catch (e) {
      debugPrint('startRonda location error: $e');
      return "Couldn't get your location. Move to an open area and try again.";
    }

    final start = await AuthService.instance.postAuthed(
      '/gobiker/active/start',
    );
    if (!start.ok) return start.message;

    _distance.reset();
    _latest = first;
    _sent = null;
    _active = true;
    _startedAt = DateTime.now();
    await _persist();

    try {
      await WakelockPlus.enable();
    } catch (_) {}

    _startStream();
    _track(first.position);
    await _send(first);
    if (!_active) return null; // the server rejected the first location
    _timer = Timer.periodic(_interval, (_) => _tick());
    return null;
  }

  /// Continue a ronda after the app was closed or killed.
  /// It does NOT call /active/start, because that would reset the
  /// start time on the server.
  /// Returns null on success, otherwise a message to show to the user.
  Future<String?> resumeRonda(SavedRonda saved) async {
    if (_active) return null;

    final accessError = await _ensureLocationAccess();
    if (accessError != null) return accessError;

    Fix first;
    try {
      first = await _currentFix();
    } catch (e) {
      debugPrint('resumeRonda location error: $e');
      return "Couldn't get your location. Move to an open area and try again.";
    }

    _startedAt = saved.startedAt;
    // Continue the saved distance; the gap while the app was closed is not counted.
    _distance.reset(meters: saved.distanceMeters);
    rondaBarangay = saved.barangay;
    rondaPatients = saved.patientsCount;
    _track(first.position);
    _latest = first;
    _sent = null;
    _active = true;

    try {
      await WakelockPlus.enable();
    } catch (_) {}

    _startStream();
    await _send(first);
    if (!_active) return null; // the server rejected the location
    _timer = Timer.periodic(_interval, (_) => _tick());
    return null;
  }

  Future<void> stopRonda() async {
    if (!_active) return;
    await _shutdown();
    _startedAt = null;
    await RondaStore.clear();
    await RondaStore.setPendingStop(true); // "server still needs to know"
    await flushPendingStop(); // try now; retried later if offline
  }

  /// Tells the server the ronda ended. If the phone is offline,
  /// the flag stays and we try again next time the dashboard opens.
  Future<void> flushPendingStop() async {
    if (!await RondaStore.hasPendingStop()) return;
    final res = await AuthService.instance.postAuthed('/gobiker/active/stop');
    if (res.ok || res.status == 404) {
      await RondaStore.setPendingStop(false);
    }
  }

  /// Gets a location locally for the emergency flow.
  /// Returns null when a location is available, otherwise an error message.
  Future<String?> prepareEmergencyLocation() async {
    // During a ronda, reuse the position already available to tracking.
    if (_active && _latest != null) return null;

    final accessError = await _ensureLocationAccess(forEmergency: true);
    if (accessError != null) return accessError;
    try {
      _latest = await _currentFix();
    } catch (e) {
      debugPrint('prepareEmergencyLocation error: $e');
      return "Couldn't get your location. If this is urgent, call 911 directly.";
    }
    return null;
  }

  // ---------------------------------------------------------------- internals

  /// Saves the ronda on the phone so it survives an app close.
  Future<void> _persist() async {
    final started = _startedAt;
    if (started == null) return;
    await RondaStore.save(
      SavedRonda(
        startedAt: started,
        distanceMeters: _distance.meters,
        patientsCount: rondaPatients,
        barangay: rondaBarangay,
      ),
    );
    debugPrint('Ronda saved'); // temporary: delete after testing
  }

  /// [forEmergency]: the message is about the alert, not a ronda (an alert can be
  /// sent without being on ronda).
  Future<String?> _ensureLocationAccess({bool forEmergency = false}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return forEmergency
          ? "Turn on your phone's location (GPS) so the admin can see where you are."
          : "Turn on your phone's location (GPS) to start a ronda.";
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return forEmergency
          ? 'Location permission is needed so the Go Bike admin can see where you are.'
          : 'Location permission is needed to share your position with the Go Bike admin during a ronda.';
    }
    if (permission == LocationPermission.deniedForever) {
      return 'Location permission is blocked. Enable it for this app in your phone settings.';
    }
    return null;
  }

  /// The best reading the phone can give right now (also used by the live
  /// map). Throws when there is none.
  Future<Fix> bestFix() => _currentFix();

  Future<Fix> _currentFix() async {
    // 1) Best accuracy first (works outdoors)
    try {
      return Fix(
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        ),
      );
    } catch (e) {
      debugPrint('High accuracy failed: $e');
    }

    // 2) Wi-Fi / cell tower location (works indoors)
    try {
      return Fix(
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Medium accuracy failed: $e');
    }

    // 3) Last known position, if the phone has one. It can be hours old: it
    // is sent with its real age, and the server keeps it off the map if so.
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) return Fix.lastKnown(last);

    throw Exception('No location available');
  }

  /// Keeps location updates coming, and shows the foreground notification
  /// that stops Android from pausing the app in the background.
  void _startStream() {
    _stream?.cancel();
    final settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
      intervalDuration: const Duration(seconds: 3),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'RondaGo: ronda in progress',
        notificationText: 'Sharing your live location with the Go Bike admin.',
        enableWakeLock: true,
        setOngoing: true,
      ),
    );
    _stream = Geolocator.getPositionStream(locationSettings: settings)
        .listen((p) {
          _latest = Fix(p);
          _track(p); // accumulate distance on every stream update (~3s)
        }, onError: (Object e) => debugPrint('Location stream error: $e'));
  }

  void _track(Position p) {
    _distance.add(
      GpsFix(
        latitude: p.latitude,
        longitude: p.longitude,
        accuracy: p.accuracy,
        time: p.timestamp,
        speed: p.speed,
      ),
    );
  }

  Future<void> _tick() async {
    if (!_active || _sending) return;
    _sending = true;
    try {
      var fix = _latest;
      if (fix == null || fix.age >= _freshFor) {
        // The stream has gone quiet (indoors, or the phone is saving power):
        // ask the phone directly.
        try {
          final asked = await _currentFix();
          if (fix == null || asked.at.isAfter(fix.at)) {
            fix = asked;
            _latest = asked;
            _track(asked.position);
          }
        } catch (e) {
          // Nothing new. The reading we still have is sent with its real age
          // below: it no longer moves the dot, but it keeps this GoBiker
          // online, and so someone the admin can still send to an emergency.
          debugPrint('No new position: $e');
        }
      }
      await _persist();
      if (fix == null) return;

      final sentAt = _sentAt;
      final sinceSent = sentAt == null
          ? Duration.zero
          : DateTime.now().difference(sentAt);
      if (Fix.worthSending(fix, sent: _sent, sinceSent: sinceSent)) {
        await _send(fix);
      }
    } catch (e) {
      debugPrint('Location update skipped: $e');
    } finally {
      _sending = false;
    }
  }

  Future<void> _send(Fix fix) async {
    final res = await AuthService.instance.postAuthed(
      '/gobiker/location',
      body: fix.toJson(),
    );
    if (res.ok) {
      _sent = fix;
      _sentAt = DateTime.now();
      return;
    }

    // 401/403: the login expired or the account is not allowed to track.
    if (res.status == 401 || res.status == 403) {
      await _shutdown();
      onFatalError?.call(res.message);
    }
  }

  Future<void> _shutdown() async {
    _active = false;
    _timer?.cancel();
    _timer = null;
    await _stream?.cancel();
    _stream = null;
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }
}
