import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:go_bike_app/core/distance_tracker.dart';

// Poblacion, Bugallon.
const _lat = 15.9566;
const _lng = 120.1866;
const _metersPerDegLat = 111320.0;
final _metersPerDegLng = 111320.0 * math.cos(_lat * math.pi / 180);
final _t0 = DateTime(2026, 10, 24, 8);

/// A reading [north] / [east] metres from the start, [seconds] into the ronda.
GpsFix _fix(
  double north,
  double east,
  int seconds, {
  double accuracy = 8,
  double speed = -1,
}) => GpsFix(
  latitude: _lat + north / _metersPerDegLat,
  longitude: _lng + east / _metersPerDegLng,
  accuracy: accuracy,
  time: _t0.add(Duration(seconds: seconds)),
  speed: speed,
);

void main() {
  test('standing still for 10 minutes adds nothing despite GPS drift', () {
    final tracker = DistanceTracker();
    final random = math.Random(42);

    // A reading every 5 s that wanders around the same spot by up to the
    // phone's own error estimate, like a phone on a parked bike.
    for (var s = 0; s <= 600; s += 5) {
      final accuracy = 5 + random.nextDouble() * 10;
      final drift = random.nextDouble() * accuracy;
      final angle = random.nextDouble() * 2 * math.pi;
      tracker.add(
        _fix(
          drift * math.cos(angle),
          drift * math.sin(angle),
          s,
          accuracy: accuracy,
          speed: random.nextDouble() * 0.3,
        ),
      );
    }

    expect(tracker.meters, 0);
  });

  test('riding 1 km in a straight line counts about 1 km', () {
    final tracker = DistanceTracker();
    final random = math.Random(7);

    // 15 km/h ≈ 4.2 m/s, a reading every 5 s, with a few metres of noise.
    for (var s = 0; s <= 240; s += 5) {
      final along = s * 4.17;
      tracker.add(
        _fix(
          along + random.nextDouble() * 4 - 2,
          random.nextDouble() * 4 - 2,
          s,
        ),
      );
    }

    expect(tracker.meters, closeTo(1000, 60));
  });

  test('walking slowly still adds up', () {
    final tracker = DistanceTracker();
    // 1 m/s: each reading is only 5 m on, below the noise threshold.
    for (var s = 0; s <= 200; s += 5) {
      tracker.add(_fix(s * 1.0, 0, s, accuracy: 5));
    }

    expect(tracker.meters, closeTo(200, 20));
  });

  test('a drift jump bigger than the error is ignored while the phone reports no speed', () {
    final tracker = DistanceTracker()..add(_fix(0, 0, 0, accuracy: 6));

    // 30 m away (twice the 15 m threshold) but the phone says 0.1 m/s.
    expect(tracker.add(_fix(30, 0, 5, accuracy: 6, speed: 0.1)), 0);
    // Moving for real: the speed reading agrees, and the step counts.
    expect(tracker.add(_fix(30, 0, 10, accuracy: 6, speed: 4)), closeTo(30, 1));
  });

  test('vague Wi-Fi or cell-tower positions are ignored', () {
    final tracker = DistanceTracker()..add(_fix(0, 0, 0));

    expect(tracker.add(_fix(80, 0, 10, accuracy: 60)), 0);
    expect(tracker.meters, 0);
  });

  test('a GPS glitch that jumps far in a moment is ignored', () {
    final tracker = DistanceTracker()..add(_fix(0, 0, 0));

    // 900 m in 5 s would be 650 km/h.
    expect(tracker.add(_fix(900, 0, 5)), 0);
    // Real riding continues to count from the last good point.
    expect(tracker.add(_fix(40, 0, 10)), closeTo(40, 1));
  });

  test('a resumed ronda keeps its distance and skips the gap', () {
    final tracker = DistanceTracker()
      ..reset(meters: 1500)
      ..add(_fix(0, 0, 0))
      // The app was closed and the GoBiker moved 2 km meanwhile.
      ..add(_fix(2000, 0, 3600));

    // The first reading after resuming is only a starting point.
    final resumed = DistanceTracker()..reset(meters: 1500);
    resumed.add(_fix(2000, 0, 3600));
    expect(resumed.meters, 1500);
    expect(
      tracker.meters,
      greaterThan(1500),
    ); // control: continuous tracking counts it
  });
}
