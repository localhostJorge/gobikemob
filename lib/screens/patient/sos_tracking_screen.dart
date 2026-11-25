import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/resident_sos.dart';
import '../../core/routing_service.dart';
import '../../core/sos_tracking.dart';
import '../../core/theme.dart';
import '../../widgets/bottom_gap.dart';
import '../../widgets/initials_avatar.dart';
import '../live_map_screen.dart' show formatDistance, formatRideTime, sosRed;
import 'app_colors.dart';
import 'ui_kit.dart';

/// The resident's own SOS on a map, with the GoBikers the admin sent coming
/// towards it, live.
///
/// Before a GoBiker is sent, it shows the SOS pin and says it is waiting. Once
/// one is on the way, their marker moves as their phone reports, with the road
/// route and how long they should take. When the admin sent several, each one
/// with a position gets a marker; the route and the glide follow the first. When the SOS is over, the server stops
/// sharing where they are and the map says so.
class SosTrackingScreen extends StatefulWidget {
  const SosTrackingScreen({super.key, required this.sosId, this.path});

  final int sosId;

  /// Where to ask for it; null for a resident's SOS
  /// (`/resident/sos/{id}/tracking`).
  final String? path;

  @override
  State<SosTrackingScreen> createState() => _SosTrackingScreenState();
}

class _SosTrackingScreenState extends State<SosTrackingScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// The GoBiker's app reports every few seconds while they ride.
  static const Duration _refresh = Duration(seconds: 4);
  static const LatLng _fallbackCenter = LatLng(15.9566, 120.1866); // Bugallon

  /// The GoBiker left the drawn route by this much: ask for a new one.
  static const double _rerouteMetres = 60;
  static const Duration _maxRouteAge = Duration(seconds: 60);
  static const Duration _retryRouteAfter = Duration(seconds: 20);

  final _map = MapController();
  late final AnimationController _glide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  Timer? _timer;
  bool _fetching = false;
  SosTracking? _data;
  String? _error;

  /// Where the resident is: the SOS pin, else the phone's own position.
  LatLng? _phone;

  /// The first GoBiker's marker slides from [_from] to [_to] on each update.
  LatLng? _from;
  LatLng? _to;

  RoadRoute? _route;
  bool _routing = false;
  bool _routeFailed = false;
  LatLng? _routedFrom;
  DateTime? _routedAt;

  /// The camera has been fitted to everyone once; after that the resident
  /// pans freely and "Show us both" / "Show everyone" brings it back.
  bool _fitted = false;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _timer = Timer.periodic(_refresh, (_) => _load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _glide.dispose();
    super.dispose();
  }

  /// No polling while the app is in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _timer ??= Timer.periodic(_refresh, (_) => _load());
      _load();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> _load() async {
    if (_fetching) return;
    _fetching = true;
    final result = await SosTracking.load(widget.sosId, path: widget.path);
    _fetching = false;
    if (!mounted) return;

    final data = result.data;
    if (data == null) {
      setState(() => _error = result.error);
      return;
    }

    // The SOS was sent without a GPS pin: show the phone's own position.
    if (data.sosPoint == null && _phone == null) _locatePhone();

    final next = data.responders.firstOrNull?.point;
    setState(() {
      _error = null;
      _data = data;
      if (next == null) {
        _from = _to = null;
        _route = null;
      } else if (_to == null) {
        _from = _to = next;
      } else if (_to != next) {
        _from = _drawnGobiker ?? _to;
        _to = next;
        _glide.forward(from: 0);
      }
    });

    if (!data.isOpen) {
      // Over: the server no longer shares the GoBiker; nothing left to poll.
      _timer?.cancel();
      _timer = null;
      ResidentSos.instance.load(); // the Safety tab drops the card
    }

    _fitOnce();
    _maybeRoute();
  }

  Future<void> _locatePhone() async {
    final p = await ResidentSos.positionSource();
    if (p == null || !mounted) return;
    setState(() => _phone = LatLng(p.latitude, p.longitude));
    _fitOnce();
  }

  LatLng? get _destination => _data?.sosPoint ?? _phone;

  LatLng? get _drawnGobiker {
    final from = _from, to = _to;
    if (from == null || to == null) return to;
    final t = Curves.easeInOut.transform(_glide.value);
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
  }

  /// Ask for the road route from the GoBiker to the SOS when there is none
  /// yet, when they left it, or every minute.
  Future<void> _maybeRoute() async {
    final from = _to, to = _destination;
    if (from == null || to == null || _routing) return;
    final age = _routedAt == null
        ? null
        : DateTime.now().difference(_routedAt!);
    if (_routeFailed && age != null && age < _retryRouteAfter) return;
    final moved = _routedFrom == null
        ? double.infinity
        : const Distance().as(LengthUnit.Meter, _routedFrom!, from);
    if (_route != null &&
        moved < _rerouteMetres &&
        age != null &&
        age < _maxRouteAge) {
      return;
    }

    _routing = true;
    final route = await fetchRoadRoute(
      fromLat: from.latitude,
      fromLng: from.longitude,
      toLat: to.latitude,
      toLng: to.longitude,
    );
    if (!mounted) return;
    setState(() {
      _routing = false;
      _routedAt = DateTime.now();
      _routedFrom = from;
      _routeFailed = route == null;
      if (route != null || _route == null) _route = route;
    });
  }

  void _fitOnce() {
    if (_fitted || !_mapReady) return;
    final gobiker = _to, me = _destination;
    if (me == null) return;
    if (gobiker == null) {
      // Only the SOS so far: centre on it, and fit again once a GoBiker shows.
      _map.move(me, 16);
      return;
    }
    _fitted = true;
    _fitBoth();
  }

  void _fitBoth() {
    final points = [?_to, for (final r in _others) ?r.point, ?_destination];
    if (points.isEmpty) return;
    if (points.length == 1) {
      _map.move(points.single, 16);
      return;
    }
    _map.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.fromLTRB(60, 140, 60, 260),
        maxZoom: 17,
      ),
    );
  }

  /// The GoBikers after the first: drawn where their phone said, no glide.
  List<TrackedResponder> get _others =>
      _data?.responders.skip(1).toList() ?? const [];

  double? get _straightMetres {
    final a = _to, b = _destination;
    if (a == null || b == null) return null;
    return const Distance().as(LengthUnit.Meter, a, b);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final responder = data?.responders.firstOrNull;
    final destination = _destination;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your SOS'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _fallbackCenter,
              initialZoom: 14,
              maxZoom: 19,
              onMapReady: () {
                _mapReady = true;
                _fitOnce();
              },
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.gobikeproject.app',
                maxZoom: 19,
              ),
              if (_to != null && destination != null)
                PolylineLayer(
                  polylines: [
                    if (_route case final route?)
                      Polyline(
                        points: route.points,
                        color: AppTheme.orange,
                        strokeWidth: 5,
                        borderColor: Colors.white,
                        borderStrokeWidth: 2,
                      )
                    else
                      Polyline(
                        points: [_to!, destination],
                        color: AppColors.textMuted,
                        strokeWidth: 3,
                        borderColor: Colors.white,
                        borderStrokeWidth: 1,
                        pattern: StrokePattern.dashed(segments: const [12, 8]),
                      ),
                  ],
                ),
              AnimatedBuilder(
                animation: _glide,
                builder: (context, _) {
                  final g = _drawnGobiker;
                  return MarkerLayer(
                    markers: [
                      if (destination != null)
                        Marker(
                          point: destination,
                          width: 44,
                          height: 44,
                          alignment: Alignment.topCenter,
                          child: Semantics(
                            label: 'Your SOS location',
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: sosRed,
                              size: 44,
                              shadows: [
                                Shadow(color: Colors.black38, blurRadius: 6),
                              ],
                            ),
                          ),
                        ),
                      for (final r in _others)
                        if (r.point case final p?)
                          Marker(
                            point: p,
                            width: 44,
                            height: 44,
                            child: _GobikerDot(responder: r),
                          ),
                      // The first last, so it sits on top.
                      if (g != null && responder != null)
                        Marker(
                          point: g,
                          width: 44,
                          height: 44,
                          child: _GobikerDot(responder: responder),
                        ),
                    ],
                  );
                },
              ),
              Padding(
                padding: EdgeInsets.only(bottom: bottomGap(context) + 200),
                child: const SimpleAttributionWidget(
                  source: Text('OpenStreetMap contributors'),
                  alignment: Alignment.bottomLeft,
                ),
              ),
            ],
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12 + bottomGap(context),
            child: SosTrackingPanel(
              data: data,
              error: _error,
              route: _route,
              routing: _routing,
              straightMetres: _straightMetres,
              destination: destination,
              onShowBoth: _fitBoth,
            ),
          ),
        ],
      ),
    );
  }
}

/// The GoBiker on the map: their photo or initials in an orange ring, greyed
/// out while their app is not reporting.
class _GobikerDot extends StatelessWidget {
  const _GobikerDot({required this.responder});

  final TrackedResponder responder;

  @override
  Widget build(BuildContext context) {
    final color = responder.online ? AppTheme.orange : AppColors.textMuted;
    return Semantics(
      label: '${responder.name}, your GoBiker',
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
        ),
        child: InitialsAvatar(
          responder.name,
          imageUrl: responder.photoUrl,
          radius: 19,
          color: color,
        ),
      ),
    );
  }
}

/// What the resident is told under the map: who is coming and how far away
/// they are, or why nobody is shown.
class SosTrackingPanel extends StatelessWidget {
  const SosTrackingPanel({
    super.key,
    required this.data,
    this.error,
    this.route,
    this.routing = false,
    this.straightMetres,
    this.destination,
    this.onShowBoth,
    this.now,
  });

  final SosTracking? data;
  final String? error;

  /// The road route and straight distance are for the first GoBiker.
  final RoadRoute? route;
  final bool routing;
  final double? straightMetres;

  /// Where help is going, for how far the other GoBikers are. Falls back to
  /// the SOS pin.
  final LatLng? destination;
  final VoidCallback? onShowBoth;

  /// For tests: the clock "last seen" is worked out against.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final d = data;
    final all = d?.responders ?? const <TrackedResponder>[];
    final r = all.firstOrNull;
    final to = destination ?? d?.sosPoint;

    late final Widget body;
    if (d == null) {
      body = _Line(
        icon: error == null ? Icons.hourglass_top_rounded : Icons.wifi_off,
        color: error == null ? pal.muted : pal.redText,
        title: error == null ? 'Loading your SOS…' : 'Could not load the map',
        detail: error ?? 'One moment.',
      );
    } else if (!d.isOpen) {
      body = _Line(
        icon: Icons.check_circle_rounded,
        color: pal.greenText,
        title: d.cancelled ? 'You cancelled this SOS' : 'Your SOS is resolved',
        detail: 'The GoBiker is no longer shown on the map.',
      );
    } else if (r == null) {
      body = _Line(
        icon: Icons.support_agent_rounded,
        color: pal.orangeText,
        title: 'Waiting for a GoBiker',
        detail:
            'The Go Bike admin has your SOS. As soon as a GoBiker is sent, '
            'you will see them coming here.',
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Responder(
            responder: r,
            route: route,
            routing: routing,
            straightMetres: straightMetres,
            now: now,
          ),
          for (final other in all.skip(1)) ...[
            const Divider(height: Sp.lg),
            _Responder(
              responder: other,
              straightMetres: switch ((other.point, to)) {
                (final a?, final b?) => const Distance().as(
                  LengthUnit.Meter,
                  a,
                  b,
                ),
                _ => null,
              },
              now: now,
            ),
          ],
        ],
      );
    }

    return Semantics(
      liveRegion: true,
      container: true,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(Rd.card),
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(Sp.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              body,
              if (r != null && onShowBoth != null) ...[
                const SizedBox(height: Sp.md),
                SecondaryButton(
                  label: all.length > 1 ? 'Show everyone' : 'Show us both',
                  icon: Icons.zoom_out_map_rounded,
                  onPressed: onShowBoth,
                ),
              ],
              if (d != null && d.isOpen && error != null) ...[
                const SizedBox(height: Sp.sm),
                Text(
                  'Not updating: $error',
                  style: T.meta.copyWith(color: pal.redText),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Responder extends StatelessWidget {
  const _Responder({
    required this.responder,
    this.route,
    this.routing = false,
    this.straightMetres,
    this.now,
  });

  final TrackedResponder responder;
  final RoadRoute? route;
  final bool routing;
  final double? straightMetres;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final r = responder;

    String status;
    Color statusColor = pal.orangeText;
    if (!r.hasPosition) {
      status = 'On the way · their location will show here soon';
    } else if (!r.online) {
      final seen = r.positionAt == null
          ? ''
          : ' ${sinceLabel(r.positionAt!, now: now)}';
      status = 'Last seen$seen · their app may have lost signal';
      statusColor = pal.muted;
    } else {
      status = 'On the way to you';
    }

    String? distance;
    if (route case final route?) {
      distance =
          '${formatDistance(route.distanceMetres)} by road · '
          '~${formatRideTime(route.durationSeconds)}';
    } else if (straightMetres case final m?) {
      distance = routing
          ? '${formatDistance(m)} away · finding the road…'
          : '${formatDistance(m)} away (straight line)';
    }

    return Row(
      children: [
        InitialsAvatar(
          r.name,
          imageUrl: r.photoUrl,
          radius: 24,
          color: r.online ? AppTheme.orange : AppColors.textMuted,
        ),
        const SizedBox(width: Sp.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.name, style: T.rowTitle),
              Text(
                [
                  'GoBiker',
                  if (r.barangay case final b? when b.isNotEmpty) b,
                ].join(' · '),
                style: T.meta.muted(context),
              ),
              const SizedBox(height: Sp.xs),
              Text(status, style: T.label.copyWith(color: statusColor)),
              if (distance != null) ...[
                const SizedBox(height: 2),
                Text(distance, style: T.secondary),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: Sp.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: T.rowTitle.copyWith(color: color)),
              const SizedBox(height: 2),
              Text(detail, style: T.secondary.muted(context)),
            ],
          ),
        ),
      ],
    );
  }
}
