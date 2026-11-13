import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import 'distance_tracker.dart';

/// One reading of where the phone is, and when this app got it.
///
/// The time is kept by the phone's own running clock, not taken from the
/// reading: the server is told how *old* a reading is, never what time it was
/// taken, so a phone whose clock is set wrong cannot make a fresh position
/// look old and freeze its dot on the map.
class Fix {
  Fix(this.position, {DateTime? at}) : at = at ?? DateTime.now();

  /// The phone's "last known" position, which can be minutes or hours old:
  /// here the reading's own time is all there is to go by.
  factory Fix.lastKnown(Position position) {
    final now = DateTime.now();
    return Fix(
      position,
      at: position.timestamp.isAfter(now) ? now : position.timestamp,
    );
  }

  final Position position;

  /// When the app received this reading.
  final DateTime at;

  /// How long ago that was. Never negative.
  Duration get age {
    final d = DateTime.now().difference(at);
    return d.isNegative ? Duration.zero : d;
  }

  /// Metres between two readings.
  double metersTo(Fix other) =>
      DistanceTracker.distanceBetween(_gps(this), _gps(other));

  static GpsFix _gps(Fix f) => GpsFix(
    latitude: f.position.latitude,
    longitude: f.position.longitude,
    accuracy: f.position.accuracy,
    time: f.at,
  );

  /// What the server is sent. It decides from `accuracy` and `age_seconds`
  /// whether the reading is good enough to move the dot on the live map.
  Map<String, dynamic> toJson() => {
    'latitude': position.latitude,
    'longitude': position.longitude,
    'accuracy': _round(position.accuracy),
    'heading': _round(position.heading),
    'speed': _round(position.speed),
    'age_seconds': age.inSeconds,
  };

  /// Phones report NaN for a reading they do not have; JSON cannot carry it.
  static double? _round(double value) =>
      value.isFinite ? (value * 10).round() / 10 : null;

  /// The better of two readings for showing where someone is right now: one
  /// from the last [freshFor] beats an older one, then the more precise wins
  /// (the later one on a tie).
  static Fix? better(
    Fix? a,
    Fix? b, {
    Duration freshFor = const Duration(minutes: 2),
  }) {
    if (a == null || b == null) return a ?? b;
    final aFresh = a.age < freshFor;
    final bFresh = b.age < freshFor;
    if (aFresh != bFresh) return aFresh ? a : b;
    return b.position.accuracy <= a.position.accuracy ? b : a;
  }

  /// Whether a GoBiker's reading is worth sending now, given the last one the
  /// server took ([sent], [sinceSent] ago).
  ///
  /// Sent at once when they have really moved, so the dot follows them closely;
  /// otherwise only every [heartbeat], which is enough to stay "online" and
  /// spares the battery and the mobile data of a GoBiker who is standing still.
  /// A phone's position wanders by its own error while it does not move, so a
  /// step only counts as movement once it is bigger than that error.
  static bool worthSending(
    Fix next, {
    required Fix? sent,
    required Duration sinceSent,
    Duration heartbeat = const Duration(seconds: 15),
    double minMove = 8,
  }) {
    if (sent == null || sinceSent >= heartbeat) return true;
    if (identical(next, sent)) return false;
    // The same spot, but the phone is now much surer of it.
    if (next.position.accuracy < sent.position.accuracy / 2) return true;
    return next.metersTo(sent) >= math.max(minMove, next.position.accuracy);
  }
}
