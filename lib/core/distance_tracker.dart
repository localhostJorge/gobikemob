import 'dart:math' as math;

/// One GPS reading: where, how sure the phone is (radius in metres), and when.
class GpsFix {
  const GpsFix({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.time,
    this.speed = -1,
  });

  final double latitude;
  final double longitude;

  /// The phone's own estimate of its error, in metres (smaller is better).
  final double accuracy;
  final DateTime time;

  /// The phone's own speed reading in m/s (from the satellites' Doppler
  /// shift, which stays near 0 while standing still even when the position
  /// drifts). Negative when the phone did not report one.
  final double speed;
}

/// Adds up the distance of a ronda from GPS readings without counting the
/// wandering of the GPS while the GoBiker stands still.
///
/// A phone's position drifts by 5-20 m even when it doesn't move (more
/// indoors). Two drifting readings can be up to twice the GPS error apart, so
/// a reading only counts as movement when it is further than that from the
/// last counted point. That point stays put until then, so slow movement
/// still adds up in bigger steps instead of being lost.
class DistanceTracker {
  /// Readings less precise than this (Wi-Fi / cell-tower positions) never
  /// count toward the distance. They are still fine for the live map.
  static const double maxAccuracy = 25;

  /// The smallest step that can count, even with very precise readings.
  static const double minStep = 15;

  /// Below this phone-reported speed (m/s) the GoBiker is standing still.
  static const double stillSpeed = 0.5;

  /// Faster than this (72 km/h) is a GPS glitch, not a bike.
  static const double maxSpeed = 20;

  double _meters = 0;
  GpsFix? _anchor; // the last point that was counted

  double get meters => _meters;

  /// Starts over (a new ronda), or continues from [meters] (a resumed one).
  /// The next reading becomes the starting point and adds nothing, so a gap
  /// while the app was closed is never counted.
  void reset({double meters = 0}) {
    _meters = meters;
    _anchor = null;
  }

  /// Returns how many metres this reading added (0 when it was ignored).
  double add(GpsFix fix) {
    if (fix.accuracy.isNaN || fix.accuracy <= 0 || fix.accuracy > maxAccuracy) {
      return 0;
    }

    final anchor = _anchor;
    if (anchor == null) {
      _anchor = fix;
      return 0;
    }

    final step = distanceBetween(anchor, fix);
    final noise = math.max(
      minStep,
      2 * math.max(anchor.accuracy, fix.accuracy),
    );
    if (step <= noise) return 0; // still inside the GPS error: not movement

    // The phone says it is standing still: a modest jump is drift. A real
    // move still counts once it is clearly beyond the error (nothing is
    // lost, because the starting point has not moved).
    final standing = fix.speed >= 0 && fix.speed < stillSpeed;
    if (standing && step <= 3 * noise) return 0;

    final seconds = fix.time.difference(anchor.time).inMilliseconds / 1000;
    if (seconds > 0 && step / seconds > maxSpeed) return 0; // a glitch

    _meters += step;
    _anchor = fix;
    return step;
  }

  /// Great-circle distance in metres (haversine).
  static double distanceBetween(GpsFix a, GpsFix b) {
    const earthRadius = 6371000.0;
    double rad(double deg) => deg * math.pi / 180;
    final dLat = rad(b.latitude - a.latitude);
    final dLng = rad(b.longitude - a.longitude);
    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(a.latitude)) *
            math.cos(rad(b.latitude)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * earthRadius * math.asin(math.min(1, math.sqrt(h)));
  }
}
