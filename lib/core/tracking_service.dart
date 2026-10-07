import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'auth_service.dart';
import 'ronda_store.dart';

/// Starts/stops a ronda on the server and sends the Go Biker's position
/// every 10 seconds while the ronda is active. A foreground service keeps
/// this running when the screen is locked or the app is in the background.
class TrackingService {
  TrackingService._();
  static final TrackingService instance = TrackingService._();

  static const Duration _interval = Duration(seconds: 10);
  static const Duration _freshFor = Duration(seconds: 20);

  Timer? _timer;
  StreamSubscription<Position>? _stream;
  bool _active = false;
  bool _sending = false;
  Position? _lastPosition; // used to add up the distance
  Position? _latest; // newest position from the location stream
  DateTime? _latestAt;
  double _distanceMeters = 0;
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
      final p = _latest;
      if (locError != null || p == null) {
        return (
          ok: false,
          status: 0,
          message: locError ?? "Couldn't get your location.",
        );
      }

      final res = await AuthService.instance.postAuthed(
        '/gobiker/emergency',
        body: {'latitude': p.latitude, 'longitude': p.longitude},
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
  double get distanceKm => _distanceMeters / 1000;

  /// Returns null on success, otherwise a message to show to the user.
  Future<String?> startRonda() async {
    if (_active) return null;

    final accessError = await _ensureLocationAccess();
    if (accessError != null) return accessError;

    Position first;
    try {
      first = await _currentPosition();
    } catch (e) {
      debugPrint('startRonda location error: $e');
      return "Couldn't get your location. Move to an open area and try again.";
    }

    final start = await AuthService.instance.postAuthed(
      '/gobiker/active/start',
    );
    if (!start.ok) return start.message;

    _distanceMeters = 0;
    _lastPosition = null;
    _latest = first;
    _latestAt = DateTime.now();
    _active = true;
    _startedAt = DateTime.now();
    await _persist();

    try {
      await WakelockPlus.enable();
    } catch (_) {}

    _startStream();
    _track(first);
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

    Position first;
    try {
      first = await _currentPosition();
    } catch (e) {
      debugPrint('resumeRonda location error: $e');
      return "Couldn't get your location. Move to an open area and try again.";
    }

    _startedAt = saved.startedAt;
    _distanceMeters = saved.distanceMeters;
    rondaBarangay = saved.barangay;
    rondaPatients = saved.patientsCount;
    _lastPosition = first; // don't count the gap while the app was closed
    _latest = first;
    _latestAt = DateTime.now();
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
    Position? p;

    if (_active && _latest != null) {
      // During a ronda, reuse the position already available to tracking.
      p = _latest;
    } else {
      final accessError = await _ensureLocationAccess();
      if (accessError != null) return accessError;
      try {
        p = await _currentPosition();
      } catch (e) {
        debugPrint('prepareEmergencyLocation error: $e');
        return "Couldn't get your location. If this is urgent, call 911 directly.";
      }
    }

    _latest = p;
    _latestAt = DateTime.now();
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
        distanceMeters: _distanceMeters,
        patientsCount: rondaPatients,
        barangay: rondaBarangay,
      ),
    );
    debugPrint('Ronda saved'); // temporary: delete after testing
  }

  Future<String?> _ensureLocationAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return "Turn on your phone's location (GPS) to start a ronda.";
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return 'Location permission is needed to share your position to the Go Bike during a ronda.';
    }
    if (permission == LocationPermission.deniedForever) {
      return 'Location permission is blocked. Enable it for this app in your phone settings.';
    }
    return null;
  }

  Future<Position> _currentPosition() async {
    // 1) Best accuracy first (works outdoors)
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (e) {
      debugPrint('High accuracy failed: $e');
    }

    // 2) Wi-Fi / cell tower location (works indoors)
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('Medium accuracy failed: $e');
    }

    // 3) Last known position, if the phone has one
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) return last;

    throw Exception('No location available');
  }

  /// Keeps location updates coming, and shows the foreground notification
  /// that stops Android from pausing the app in the background.
  void _startStream() {
    _stream?.cancel();
    final settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
      intervalDuration: const Duration(seconds: 5),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Go Bike ronda in progress',
        notificationText: 'Sharing your live location to the Go Bike.',
        enableWakeLock: true,
        setOngoing: true,
      ),
    );
    _stream = Geolocator.getPositionStream(locationSettings: settings)
        .listen((p) {
          _latest = p;
          _latestAt = DateTime.now();
          _track(p); // accumulate distance on every stream update (~5s)
        }, onError: (Object e) => debugPrint('Location stream error: $e'));
  }

  void _track(Position p) {
    final last = _lastPosition;
    if (last == null) {
      _lastPosition = p;
      return;
    }
    final meters = Geolocator.distanceBetween(
      last.latitude,
      last.longitude,
      p.latitude,
      p.longitude,
    );
    if (meters < 3) return; // GPS jitter while standing still
    if (meters < 2000) _distanceMeters += meters; // ignore impossible jumps
    _lastPosition = p;
  }

  Future<void> _tick() async {
    if (!_active || _sending) return;
    _sending = true;
    try {
      final at = _latestAt;
      final latest = _latest;
      final isFresh =
          latest != null &&
          at != null &&
          DateTime.now().difference(at) < _freshFor;

      final Position p = isFresh ? latest : await _currentPosition();
      _track(p);
      await _persist();
      await _send(p);
    } catch (e) {
      debugPrint('Location update skipped: $e');
    } finally {
      _sending = false;
    }
  }

  Future<void> _send(Position p) async {
    final res = await AuthService.instance.postAuthed(
      '/gobiker/location',
      body: {'latitude': p.latitude, 'longitude': p.longitude},
    );
    if (res.ok) return;

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
