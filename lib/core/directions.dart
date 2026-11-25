import 'package:latlong2/latlong.dart';

import 'live_map.dart';
import 'routing_service.dart';

/// The way to the emergency a GoBiker asked directions to: which SOS, the
/// road route drawn to it, and when that route needs asking for again.
///
/// It holds its own copy of the SOS, so one map refresh that leaves the SOS
/// out (a slow server, a hiccup) never takes the directions off the screen.
/// They close only once the server has said it is over.
class DirectionsTracker {
  /// Further than this from the drawn route: the GoBiker took another road.
  static const double offRouteMetres = 60;

  /// The resident's pin moved this far: route to where they are now.
  static const double pinMovedMetres = 30;

  /// Even on the route, ask again this often (the road may have changed).
  static const Duration maxRouteAge = Duration(seconds: 60);

  /// After a failed attempt, wait this long before trying again on its own.
  static const Duration retryAfter = Duration(seconds: 20);

  /// Refreshes in a row the SOS may be missing from before it counts as
  /// gone (declined, or the admin sent someone else).
  static const int missesToClose = 2;

  AssignedSos? target;
  RoadRoute? route;

  /// A request is in flight.
  bool routing = false;

  /// The last attempt found no road route: a straight line is drawn.
  bool failed = false;

  LatLng? _routedTo;
  DateTime? _routedAt;
  int _misses = 0;

  bool get active => target != null;

  LatLng? get destination {
    final t = target;
    if (t == null || !t.hasPosition) return null;
    return LatLng(t.latitude!, t.longitude!);
  }

  /// Directions to [sos] start: anything drawn for another SOS is dropped.
  void start(AssignedSos sos) {
    if (target?.id != sos.id) {
      // An answer still on its way is for the old SOS: the screen drops it.
      route = null;
      routing = false;
      failed = false;
      _routedTo = null;
      _routedAt = null;
    }
    target = sos;
    _misses = 0;
  }

  void stop() {
    target = null;
    route = null;
    routing = false;
    failed = false;
    _routedTo = null;
    _routedAt = null;
    _misses = 0;
  }

  /// A refresh came back with [list]. Returns true when the directions have
  /// just closed because the emergency is over or no longer this GoBiker's.
  bool refresh(List<AssignedSos> list) {
    final t = target;
    if (t == null) return false;
    final now = list.where((s) => s.id == t.id).firstOrNull;
    if (now == null) {
      _misses++;
      if (_misses < missesToClose) return false;
      stop();
      return true;
    }
    _misses = 0;
    if (!now.isOpen) {
      stop();
      return true;
    }
    // Keep the last known pin if this refresh has none.
    target = now.hasPosition ? now : t;
    return false;
  }

  /// Whether a new road route should be asked for, with the GoBiker at [me].
  bool needsRoute(LatLng me, DateTime now) {
    final to = destination;
    if (to == null || routing) return false;
    final at = _routedAt;
    if (at == null) return true; // nothing asked for yet
    if (failed) return now.difference(at) >= retryAfter;
    final routedTo = _routedTo;
    if (routedTo != null &&
        const Distance().as(LengthUnit.Meter, routedTo, to) > pinMovedMetres) {
      return true;
    }
    final drawn = route;
    if (drawn != null && distanceToLine(me, drawn.points) > offRouteMetres) {
      return true;
    }
    return now.difference(at) >= maxRouteAge;
  }

  /// A request for the way to [to] is about to go out.
  void begin(LatLng to, DateTime now) {
    routing = true;
    _routedTo = to;
    _routedAt = now;
  }

  /// The answer came back ([result] null when no server had a route). A
  /// failure keeps the route already drawn, if any, rather than wiping it.
  void finish(RoadRoute? result) {
    routing = false;
    if (result != null) {
      route = result;
      failed = false;
    } else {
      failed = route == null;
    }
  }

  /// Forget when the last attempt was, so the next check asks again at once.
  void retryNow() {
    _routedAt = null;
    failed = false;
  }
}
