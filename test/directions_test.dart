import 'package:flutter_test/flutter_test.dart';
import 'package:go_bike_app/core/directions.dart';
import 'package:go_bike_app/core/live_map.dart';
import 'package:go_bike_app/core/routing_service.dart';
import 'package:latlong2/latlong.dart';

AssignedSos _sos({
  int id = 7,
  String status = 'responding',
  double? lat = 15.96,
  double? lng = 120.19,
}) => AssignedSos(
  id: id,
  status: status,
  residentName: 'Ana Reyes',
  address: 'Purok 2',
  landmark: '',
  latitude: lat,
  longitude: lng,
);

const _me = LatLng(15.95, 120.18);
final _t0 = DateTime(2026, 11, 25, 9);

RoadRoute _road() => const RoadRoute(
  points: [LatLng(15.95, 120.18), LatLng(15.95, 120.19), LatLng(15.96, 120.19)],
  distanceMetres: 2200,
  durationSeconds: 600,
);

/// Starts directions and lands a road route at [_t0].
DirectionsTracker _routed() {
  final d = DirectionsTracker()..start(_sos());
  d.begin(d.destination!, _t0);
  d.finish(_road());
  return d;
}

void main() {
  group('keeping the directions on screen', () {
    test('one refresh without the SOS does not close them', () {
      final d = DirectionsTracker()..start(_sos());
      expect(d.refresh(const []), isFalse);
      expect(d.active, isTrue);
      expect(d.destination, const LatLng(15.96, 120.19));
    });

    test('they close once the SOS stays gone (declined, reassigned)', () {
      final d = DirectionsTracker()..start(_sos());
      d.refresh(const []);
      expect(d.refresh(const []), isTrue);
      expect(d.active, isFalse);
    });

    test('coming back in between resets the count', () {
      final d = DirectionsTracker()..start(_sos());
      d.refresh(const []);
      d.refresh([_sos()]);
      expect(d.refresh(const []), isFalse);
      expect(d.active, isTrue);
    });

    test('they close as soon as the SOS comes back resolved', () {
      final d = DirectionsTracker()..start(_sos());
      expect(d.refresh([_sos(status: 'resolved')]), isTrue);
      expect(d.active, isFalse);
    });

    test('a refresh without a pin keeps the last one', () {
      final d = DirectionsTracker()..start(_sos());
      d.refresh([_sos(lat: null, lng: null)]);
      expect(d.destination, const LatLng(15.96, 120.19));
    });

    test('a failed attempt keeps the road already drawn', () {
      final d = _routed();
      d.begin(d.destination!, _t0.add(const Duration(minutes: 1)));
      d.finish(null);
      expect(d.route, isNotNull);
      expect(d.failed, isFalse);
    });

    test('switching to another SOS drops the old route', () {
      final d = _routed();
      d.start(_sos(id: 8));
      expect(d.route, isNull);
      expect(d.needsRoute(_me, _t0), isTrue);
    });
  });

  group('asking for the route again', () {
    test('right away on the first tap', () {
      final d = DirectionsTracker()..start(_sos());
      expect(d.needsRoute(_me, _t0), isTrue);
    });

    test('never while a request is in flight', () {
      final d = DirectionsTracker()..start(_sos());
      d.begin(d.destination!, _t0);
      expect(d.needsRoute(_me, _t0.add(const Duration(minutes: 5))), isFalse);
    });

    test('not on every refresh while the GoBiker is on the route', () {
      final d = _routed();
      // 3 s and 59 s later, still on the drawn road.
      expect(d.needsRoute(_me, _t0.add(const Duration(seconds: 3))), isFalse);
      expect(
        d.needsRoute(
          const LatLng(15.95, 120.185),
          _t0.add(const Duration(seconds: 59)),
        ),
        isFalse,
      );
    });

    test('once a minute has passed', () {
      final d = _routed();
      expect(d.needsRoute(_me, _t0.add(const Duration(seconds: 60))), isTrue);
    });

    test('when the GoBiker is more than 60 m off the route', () {
      final d = _routed();
      final soon = _t0.add(const Duration(seconds: 5));
      // About 55 m south of the first leg: still on it.
      expect(d.needsRoute(const LatLng(15.9495, 120.185), soon), isFalse);
      // About 110 m south: another road.
      expect(d.needsRoute(const LatLng(15.949, 120.185), soon), isTrue);
    });

    test('when the resident pin moves more than 30 m', () {
      final d = _routed();
      d.refresh([_sos(lat: 15.9605)]); // about 55 m north
      expect(d.needsRoute(_me, _t0.add(const Duration(seconds: 5))), isTrue);
    });

    test('after a failure, again after a pause or on Try again', () {
      final d = DirectionsTracker()..start(_sos());
      d.begin(d.destination!, _t0);
      d.finish(null);
      expect(d.failed, isTrue);
      expect(d.needsRoute(_me, _t0.add(const Duration(seconds: 5))), isFalse);
      expect(d.needsRoute(_me, _t0.add(const Duration(seconds: 20))), isTrue);
      d.retryNow();
      expect(d.needsRoute(_me, _t0.add(const Duration(seconds: 6))), isTrue);
    });
  });
}
