import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Whether the phone will give this app a position right now.
enum LocationState {
  /// Location is on and the app may use it.
  ready,

  /// The phone's location (GPS) is switched off.
  serviceOff,

  /// Not allowed yet; the app may ask once.
  permissionDenied,

  /// Refused with "don't ask again": only the phone's settings can change it.
  permissionDeniedForever,
}

/// What the gate needs from the phone. A test replaces it with a script.
abstract class LocationPlatform {
  Future<bool> isServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Stream<bool> serviceEnabledChanges();
  Future<bool> openLocationSettings();
  Future<bool> openAppSettings();
}

class GeolocatorPlatform implements LocationPlatform {
  const GeolocatorPlatform();

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Stream<bool> serviceEnabledChanges() => Geolocator.getServiceStatusStream()
      .map((status) => status == ServiceStatus.enabled);

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}

/// The one place that decides whether the app may ask the phone for a position.
///
/// With location switched off, asking for a position makes Android show Google's
/// "Location Accuracy" dialog. That dialog takes the screen, so when it closes the app
/// "resumes", the map asks again, and the dialog comes straight back, however many times it
/// is refused. So nothing asks the phone for a position unless [check] says [LocationState.ready]:
/// [check] only reads the phone's state and never shows anything. The person is told once, when
/// they tap the locate button, and is sent to the settings instead of being asked in a loop.
class LocationGate {
  LocationGate([this.platform = const GeolocatorPlatform()]);

  static LocationGate instance = LocationGate();

  final LocationPlatform platform;

  /// Reads the phone's location state without ever prompting.
  Future<LocationState> check() async {
    if (!await platform.isServiceEnabled()) return LocationState.serviceOff;
    return _fromPermission(await platform.checkPermission());
  }

  /// Asks for the permission (the phone's own permission dialog, which closes for good once
  /// answered). Call it only because the person did something, never from a timer or a resume.
  Future<LocationState> requestPermission() async {
    if (!await platform.isServiceEnabled()) return LocationState.serviceOff;
    var permission = await platform.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await platform.requestPermission();
    }
    return _fromPermission(permission);
  }

  /// Opens the phone settings screen that can fix [state]. Returns false when there is
  /// nothing to open (already [LocationState.ready]).
  Future<bool> openSettingsFor(LocationState state) => switch (state) {
    LocationState.serviceOff => platform.openLocationSettings(),
    LocationState.permissionDenied ||
    LocationState.permissionDeniedForever => platform.openAppSettings(),
    LocationState.ready => Future.value(false),
  };

  /// True while location is on; changes as the person switches it on or off.
  Stream<bool> get serviceEnabledChanges => platform.serviceEnabledChanges();

  static LocationState _fromPermission(LocationPermission permission) =>
      switch (permission) {
        LocationPermission.always ||
        LocationPermission.whileInUse => LocationState.ready,
        LocationPermission.deniedForever =>
          LocationState.permissionDeniedForever,
        _ => LocationState.permissionDenied,
      };

  /// What to tell the person for a state that is not [LocationState.ready].
  static String explain(LocationState state) => switch (state) {
    LocationState.serviceOff =>
      "Your phone's location is off. Turn it on to see yourself on the map.",
    LocationState.permissionDenied =>
      'Allow location access to see yourself on the map.',
    LocationState.permissionDeniedForever => 'Location access is blocked for RondaGo. Allow it in your phone settings.',
    LocationState.ready => '',
  };
}
