import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// A way along the roads from the GoBiker to an emergency.
class RoadRoute {
  const RoadRoute({
    required this.points,
    required this.distanceMetres,
    required this.durationSeconds,
  });

  /// The line to draw, following the roads.
  final List<LatLng> points;

  /// How far it is along those roads.
  final double distanceMetres;

  /// How long the ride takes, as the routing server estimates it.
  final double durationSeconds;
}

/// The routing servers, tried in order. Both speak the OSRM API.
///
/// The bike profile (run by FOSSGIS, the OpenStreetMap community server)
/// keeps a GoBiker on roads and paths a bicycle can use. The OSRM demo server
/// only knows cars; it is the fallback when the bike server does not answer.
const List<String> kRouteServers = [
  'https://routing.openstreetmap.de/routed-bike/route/v1/driving',
  'https://router.project-osrm.org/route/v1/driving',
];

/// The servers ask every app to say who it is.
const String kRoutingUserAgent = 'GoBikeApp (com.gobikeproject.app)';

const Duration _timeout = Duration(seconds: 8);

/// Asks the routing servers for the way from one point to another. Returns
/// null when none of them can give one (no connection, no road nearby): the
/// map then says so and draws a straight line instead.
Future<RoadRoute?> fetchRoadRoute({
  required double fromLat,
  required double fromLng,
  required double toLat,
  required double toLng,
}) async {
  for (final server in kRouteServers) {
    final route = await _ask(
      Uri.parse(
        '$server/$fromLng,$fromLat;$toLng,$toLat'
        '?overview=full&steps=false&geometries=polyline',
      ),
    );
    if (route != null) return route;
  }
  return null;
}

Future<RoadRoute?> _ask(Uri url) async {
  try {
    final response = await http
        .get(
          url,
          headers: {
            'Accept': 'application/json',
            'User-Agent': kRoutingUserAgent,
          },
        )
        .timeout(_timeout);
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body);
    if (data is! Map || data['code'] != 'Ok') return null;
    final routes = data['routes'];
    if (routes is! List || routes.isEmpty || routes.first is! Map) return null;
    final route = routes.first as Map;
    final geometry = route['geometry'];
    if (geometry is! String) return null;
    final points = decodePolyline(geometry);
    if (points.length < 2) return null;
    return RoadRoute(
      points: points,
      distanceMetres: (route['distance'] as num?)?.toDouble() ?? 0,
      durationSeconds: (route['duration'] as num?)?.toDouble() ?? 0,
    );
  } catch (_) {
    // A timeout, no connection or an answer we cannot read: try the next one.
    return null;
  }
}

/// Decodes an OSRM/Google encoded polyline (precision 5) into points.
List<LatLng> decodePolyline(String encoded) {
  final list = <LatLng>[];
  final len = encoded.length;
  int index = 0, lat = 0, lng = 0;

  int next() {
    int b, shift = 0, result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20 && index < len);
    return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
  }

  while (index < len) {
    lat += next();
    if (index >= len) break;
    lng += next();
    list.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return list;
}

/// The shortest distance in metres from [p] to the line through [line].
/// Used to tell when a GoBiker has left the drawn route.
double distanceToLine(LatLng p, List<LatLng> line) {
  if (line.isEmpty) return double.infinity;
  if (line.length == 1) {
    return const Distance().as(LengthUnit.Meter, p, line.first);
  }
  // Flat projection around p: fine over the few km of a ride.
  const metresPerDegree = 111320.0;
  final cosLat = math.cos(p.latitude * math.pi / 180);
  double x(LatLng q) => (q.longitude - p.longitude) * metresPerDegree * cosLat;
  double y(LatLng q) => (q.latitude - p.latitude) * metresPerDegree;

  var best = double.infinity;
  for (var i = 0; i < line.length - 1; i++) {
    final ax = x(line[i]), ay = y(line[i]);
    final bx = x(line[i + 1]), by = y(line[i + 1]);
    final dx = bx - ax, dy = by - ay;
    final lengthSq = dx * dx + dy * dy;
    var t = lengthSq == 0 ? 0.0 : -(ax * dx + ay * dy) / lengthSq;
    t = t.clamp(0.0, 1.0);
    final cx = ax + t * dx, cy = ay + t * dy;
    final d = cx * cx + cy * cy;
    if (d < best) best = d;
  }
  return math.sqrt(best);
}
