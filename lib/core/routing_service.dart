import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Calls the OSRM (Open Source Routing Machine) API to get road-following
/// directions between two points. Falls back to a straight-line estimate when
/// the request fails or OSRM is unavailable.
///
/// The returned [LatLng] list traces the road network, which the map polyline
/// will follow for natural-looking routes.
Future<List<LatLng>?> fetchRoadRoute({
  required double fromLat,
  required double fromLng,
  required double toLat,
  required double toLng,
}) async {
  // Try OSRM public server first; the /route endpoint returns geometry.
  // Use overview=simplified to get the route geometry as an encoded polyline.
  final url = Uri.parse(
    'https://router.project-osrm.org/route/v1/driving/'
    '$fromLng,$fromLat;$toLng,$toLat?'
    'overview=simplified&steps=false&geometries=polyline',
  );

  try {
    final response = await http.get(url, headers: {'Accept': 'application/json'});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['code'] == 'Ok' && data['routes'].isNotEmpty) {
        final geometry = data['routes'][0]['geometry'];
        // OSRM returns polyline encoding; decode it to LatLng list.
        return _decodePolyline(geometry);
      }
    }
  } catch (_) {
    // Any failure (network, parse error) falls through to returning null.
  }
  return null;
}

/// Decodes an OSRM/Mapbox polyline string into a list of [LatLng].
List<LatLng> _decodePolyline(String encoded) {
  final list = <LatLng>[];
  final len = encoded.length;
  int index = 0, lat = 0, lng = 0;

  while (index < len) {
    int b, shift = 0, result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lat += result;

    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lng += result;

    // Negate if required.
    if ((lat & 1) != 0) lat = ~lat;
    if ((lng & 1) != 0) lng = ~lng;

    list.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return list;
}
