import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'auth_service.dart';

/// Starts/stops a ronda on the server and sends the Go Biker's position
/// every 10 seconds while the ronda is active. Also adds up the distance.
class TrackingService {
  TrackingService._();
  static final TrackingService instance = TrackingService._();

  static const Duration _interval = Duration(seconds: 10);

  Timer? _timer;
  bool _active = false;
  bool _sending = false;
  Position? _lastPosition;
  double _distanceMeters = 0;

  /// Set by the active-ronda screen to show a toast if the server rejects us.
  void Function(String message)? onFatalError;

  bool get isActive => _active;

  /// Distance walked/ridden during the current (or last) ronda, from GPS.
  double get distanceKm => _distanceMeters / 1000;

  /// Returns null on success, otherwise a message to show to the user.
  Future<String?> startRonda() async {
    if (_active) return null;

    final accessError = await _ensureLocationAccess();
    if (accessError != null) return accessError;

    Position first;
    try {
      first = await _currentPosition();
    } catch (_) {
      return "Couldn't get your location. Move to an open area and try again.";
    }

    final start = await AuthService.instance.postAuthed(
      '/gobiker/active/start',
    );
    if (!start.ok) return start.message;

    _distanceMeters = 0;
    _lastPosition = null;
    _active = true;
    try {
      await WakelockPlus.enable(); // keep the screen on so tracking keeps running
    } catch (_) {}

    _track(first);
    await _send(first);
    if (!_active) return null; // the server rejected the first location
    _timer = Timer.periodic(_interval, (_) => _tick());
    return null;
  }

  Future<void> stopRonda() async {
    if (!_active) return;
    await _shutdown();
    await AuthService.instance.postAuthed(
      '/gobiker/active/stop',
    ); // best effort
  }

  // ---------------------------------------------------------------- internals

  Future<String?> _ensureLocationAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return "Turn on your phone's location (GPS) to start a ronda.";
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return 'Location permission is needed to share your position with the RHU during a ronda.';
    }
    if (permission == LocationPermission.deniedForever) {
      return 'Location permission is blocked. Enable it for this app in your phone settings.';
    }
    return null;
  }

  Future<Position> _currentPosition() {
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
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
    if (meters < 8) return; // GPS jitter while standing still
    if (meters < 2000) _distanceMeters += meters; // ignore impossible jumps
    _lastPosition = p;
  }

  Future<void> _tick() async {
    if (!_active || _sending) return;
    _sending = true;
    try {
      final p = await _currentPosition();
      _track(p);
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
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }
}
