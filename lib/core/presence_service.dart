import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import 'auth_service.dart';
import 'tracking_service.dart';

/// Keeps track of where the phone is while the app is open, for the live map.
///
/// A GoBiker's position is also sent on (POST /gobiker/location), which is
/// what puts them on the admin's map and on the residents' maps. A resident's
/// position is never sent anywhere: it only draws their own dot, because
/// residents are not plotted for anyone.
///
/// Stops as soon as the app goes to the background, so no background location
/// permission is needed. During a ronda the [TrackingService] already sends the
/// GoBiker's position, so this waits.
class PresenceService with WidgetsBindingObserver {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  static const Duration _interval = Duration(seconds: 15);

  Timer? _timer;
  StreamSubscription<Position>? _watch;
  int _watchers = 0;
  bool _started = false;
  bool _foreground = true;
  bool _sending = false;
  bool _askedPermission = false;

  /// The newest position this phone sent (the live map centres on it).
  final ValueNotifier<Position?> latest = ValueNotifier(null);

  /// Called by the dashboards once the user is signed in.
  void start() {
    if (_started || !AuthService.instance.isLoggedIn) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _resume();
  }

  /// On logout.
  void stop() {
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
    _watch?.cancel();
    _watch = null;
    _watchers = 0;
    latest.value = null;
    _askedPermission = false;
  }

  /// Sends a position right away (e.g. when the live map opens).
  Future<void> sendNow() => _tick();

  /// Follow the phone closely while a map is on screen, so the pin really
  /// moves as the GoBiker rides instead of hopping once every [_interval].
  ///
  /// This only draws: how often the position is *sent* is unchanged. It is
  /// also what keeps the pin alive during a ronda, when [_tick] stands aside
  /// for the [TrackingService] and so never refreshes [latest] itself.
  void watch() {
    _watchers++;
    if (_watch != null) return;
    _watch =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen(
          (p) => latest.value = p,
          onError: (Object e) => debugPrint('Position stream error: $e'),
        );
  }

  /// The map was closed. The stream stops when the last map lets go of it.
  void unwatch() {
    if (_watchers > 0) _watchers--;
    if (_watchers > 0) return;
    _watch?.cancel();
    _watch = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _foreground) return;
    _foreground = foreground;
    if (foreground) {
      _resume();
      if (_watchers > 0) {
        _watchers--; // watch() counts it back up
        watch();
      }
    } else {
      _timer?.cancel();
      _timer = null;
      // No background location permission is asked for, so the stream stops too.
      _watch?.cancel();
      _watch = null;
    }
  }

  void _resume() {
    if (!_started) return;
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _tick());
    _tick();
  }

  Future<void> _tick() async {
    final user = AuthService.instance.currentUser;
    if (!_started || !_foreground || _sending || user == null) return;
    if (user.isGoBiker && TrackingService.instance.isActive) return;
    _sending = true;
    try {
      if (!await _hasPermission()) return;
      final p = await TrackingService.instance.bestPosition();
      latest.value = p;
      // Residents keep their position to themselves.
      if (!user.isGoBiker) return;
      final res = await AuthService.instance.callAuthed(
        'POST',
        '/gobiker/location',
        body: {'latitude': p.latitude, 'longitude': p.longitude},
      );
      if (res.status == 401) stop();
    } catch (e) {
      debugPrint('Presence update skipped: $e');
    } finally {
      _sending = false;
    }
  }

  /// Asks for location access once per session; never nags after a "no".
  Future<bool> _hasPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && !_askedPermission) {
      _askedPermission = true;
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }
}
