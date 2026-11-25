import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_bike_app/core/routing_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

/// Google's documented example: (38.5, -120.2), (40.7, -120.95),
/// (43.252, -126.453). A decoder that adds the raw values up wrongly lands
/// these thousands of kilometres away, which is how routes vanished before.
const _example = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';

String _ok({double distance = 2400, double duration = 720}) => jsonEncode({
  'code': 'Ok',
  'routes': [
    {'geometry': _example, 'distance': distance, 'duration': duration},
  ],
});

Future<RoadRoute?> _route() => fetchRoadRoute(
  fromLat: 15.95,
  fromLng: 120.18,
  toLat: 15.96,
  toLng: 120.19,
);

void main() {
  test('decodes an encoded polyline to the right points', () {
    final points = decodePolyline(_example);
    expect(points, hasLength(3));
    expect(points[0].latitude, closeTo(38.5, 1e-5));
    expect(points[0].longitude, closeTo(-120.2, 1e-5));
    expect(points[1].latitude, closeTo(40.7, 1e-5));
    expect(points[1].longitude, closeTo(-120.95, 1e-5));
    expect(points[2].latitude, closeTo(43.252, 1e-5));
    expect(points[2].longitude, closeTo(-126.453, 1e-5));
  });

  test('asks the bike server first, saying who it is', () async {
    final asked = <http.Request>[];
    final route = await http.runWithClient(
      _route,
      () => MockClient((req) async {
        asked.add(req);
        return http.Response(_ok(), 200);
      }),
    );
    expect(asked, hasLength(1));
    expect(asked.single.url.toString(), startsWith(kRouteServers.first));
    expect(asked.single.url.path, endsWith('/120.18,15.95;120.19,15.96'));
    expect(asked.single.headers['User-Agent'], kRoutingUserAgent);
    expect(route, isNotNull);
    expect(route!.points, hasLength(3));
    expect(route.distanceMetres, 2400);
    expect(route.durationSeconds, 720);
  });

  test('falls back to the second server when the bike one fails', () async {
    final asked = <String>[];
    final route = await http.runWithClient(
      _route,
      () => MockClient((req) async {
        asked.add(req.url.toString());
        if (req.url.toString().startsWith(kRouteServers.first)) {
          return http.Response('busy', 503);
        }
        return http.Response(_ok(distance: 3000), 200);
      }),
    );
    expect(asked, hasLength(2));
    expect(route?.distanceMetres, 3000);
  });

  test('returns null when no server has a route', () async {
    final route = await http.runWithClient(
      _route,
      () => MockClient(
        (req) async => http.Response(jsonEncode({'code': 'NoRoute'}), 200),
      ),
    );
    expect(route, isNull);
  });

  // A widget test runs on a fake clock, so the 8 s timeouts pass at once.
  testWidgets('gives up on a server that never answers', (tester) async {
    RoadRoute? result;
    var done = false;
    http.runWithClient(
      () => _route().then((r) {
        result = r;
        done = true;
      }),
      () => MockClient((req) => Completer<http.Response>().future),
    );
    await tester.pump(const Duration(seconds: 7));
    expect(done, isFalse);
    await tester.pump(const Duration(seconds: 2)); // first server timed out
    await tester.pump(const Duration(seconds: 9)); // and the second
    expect(done, isTrue);
    expect(result, isNull);
  });

  test('distance to a line measures to the nearest segment', () {
    const a = LatLng(15.95, 120.18);
    const b = LatLng(15.95, 120.19); // about 1 km east
    // 0.0005 degrees north of the middle: about 55 m.
    final d = distanceToLine(const LatLng(15.9505, 120.185), [a, b]);
    expect(d, closeTo(55.7, 2));
    expect(distanceToLine(a, [a, b]), closeTo(0, 0.01));
  });
}
