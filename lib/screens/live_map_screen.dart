import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/auth_service.dart';
import '../core/live_map.dart';
import '../core/location_gate.dart';
import '../core/presence_service.dart';
import '../core/theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/bottom_gap.dart';
import '../widgets/confirm_modal.dart';
import '../widgets/location_help.dart';

/// SOS colors: red while waiting, yellow while a GoBiker responds, green once
/// resolved (the same colors as the admin live map).
const Color sosRed = Color(0xFFDC2626);
const Color sosYellow = Color(0xFFEAB308);
const Color sosGreen = Color(0xFF16A34A);

Color sosColor(String status) => switch (status) {
  'responding' => sosYellow,
  'resolved' => sosGreen,
  _ => sosRed,
};

/// How far there is left to go, read the way people say it: "640 m", "2.4 km".
String formatDistance(double metres) => metres < 1000
    ? '${metres.round()} m'
    : '${(metres / 1000).toStringAsFixed(1)} km';

/// GoBiker colors: blue on an ordinary ronda, orange once they are responding,
/// red while their own emergency alarm is still up.
Color gobikerColor(String status) => switch (status) {
  'responding' => AppTheme.orange,
  'emergency' => sosRed,
  _ => AppTheme.blue,
};

/// The live map. GoBikers see the other GoBikers of their barangay and the
/// exact location of the SOS requests the admin assigned to them; residents
/// see the GoBikers of their barangay and themselves.
///
/// Residents are never plotted for anyone.
class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key, this.focusSosId});

  /// Opened from an "SOS assigned" notification: centre on that request.
  final int? focusSosId;

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  static const Duration _refresh = Duration(seconds: 10);
  // Bugallon, Pangasinan: shown until the phone has a position.
  static const LatLng _fallbackCenter = LatLng(15.9566, 120.1866);

  final _map = MapController();
  Timer? _timer;
  LiveMapData _data = const LiveMapData();
  bool _loaded = false;
  String? _error;
  bool _centered = false;
  int? _focusSosId;
  int? _directionsSosId;

  bool get _isGobiker => AuthService.instance.currentUser?.isGoBiker ?? false;

  @override
  void initState() {
    super.initState();
    _focusSosId = widget.focusSosId;
    PresenceService.instance.latest.addListener(_onMyPosition);
    PresenceService.instance.watch(); // the pin moves as the GoBiker rides
    PresenceService.instance.sendNow();
    _locateMe(move: false);
    _load();
    _timer = Timer.periodic(_refresh, (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    PresenceService.instance.latest.removeListener(_onMyPosition);
    PresenceService.instance.unwatch();
    super.dispose();
  }

  Position? get _me => PresenceService.instance.latest.value;

  /// The emergency the GoBiker asked directions to, while it is still open.
  AssignedSos? get _directionsSos {
    final id = _directionsSosId;
    if (id == null) return null;

    return _data.sos
        .where((s) => s.id == id && s.hasPosition && s.isOpen)
        .firstOrNull;
  }

  /// Points the map at the emergency: both ends on screen, and the line
  /// between them. Everything stays in the app; no maps app is opened.
  void _showDirections(AssignedSos sos) {
    if (!sos.hasPosition) return;
    setState(() => _directionsSosId = sos.id);
    // Stop the map re-centring on the GoBiker the moment their position moves.
    _centered = true;
    _fitToDirections(sos);
  }

  void _fitToDirections(AssignedSos sos) {
    final me = _me;
    final there = LatLng(sos.latitude!, sos.longitude!);
    if (me == null) {
      // No position yet: show the emergency, and the line appears when it lands.
      _map.move(there, 17);
      AppToast.show(
        context,
        'Waiting for your location to draw the way there.',
      );

      return;
    }
    _map.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints([
          LatLng(me.latitude, me.longitude),
          there,
        ]),
        padding: const EdgeInsets.fromLTRB(60, 140, 60, 180),
        maxZoom: 17,
      ),
    );
  }

  /// How far the GoBiker still has to go, in a straight line.
  String? get _distanceToSos {
    final sos = _directionsSos;
    final me = _me;
    if (sos == null || me == null) return null;
    return formatDistance(
      const Distance().as(
        LengthUnit.Meter,
        LatLng(me.latitude, me.longitude),
        LatLng(sos.latitude!, sos.longitude!),
      ),
    );
  }

  void _onMyPosition() {
    if (!mounted) return;
    setState(() {}); // the pin, the line and the distance all follow from this
    final me = _me;
    if (me == null) return;

    final directions = _directionsSos;
    if (directions != null) {
      // Riding off the edge of the screen: bring both ends back into view,
      // but leave the map alone while they are still on it.
      if (!_map.camera.visibleBounds.contains(
        LatLng(me.latitude, me.longitude),
      )) {
        _fitToDirections(directions);
      }

      return;
    }
    if (!_centered && _focusSosId == null) {
      _centered = true;
      _map.move(LatLng(me.latitude, me.longitude), 16);
    }
  }

  /// Finds the phone and (when [move]) centres the map on it.
  ///
  /// [move] is true only when the person tapped the button. Anything else (opening the map)
  /// stays quiet and never asks the phone for anything while location is off: asking then opens
  /// Google's "Location Accuracy" dialog, which comes straight back when it is refused. A tap
  /// with location off or refused gets one message with a way to fix it instead.
  Future<void> _locateMe({bool move = true}) async {
    var state = await LocationGate.instance.check();
    if (!mounted) return;

    // They tapped the button: asking for the permission is fine, and the phone's own dialog
    // closes for good once answered.
    if (move && state == LocationState.permissionDenied) {
      state = await LocationGate.instance.requestPermission();
      if (!mounted) return;
    }
    if (state != LocationState.ready) {
      if (move) showLocationHelp(context, state);
      return;
    }

    try {
      final p =
          await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            ),
          );
      PresenceService.instance.latest.value ??= p;
      if (move && mounted) {
        _map.move(LatLng(p.latitude, p.longitude), 16);
      }
    } catch (_) {
      if (move && mounted) {
        AppToast.show(
          context,
          "Couldn't get your location.",
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _load() async {
    final result = await LiveMapData.fetch();
    if (!mounted) return;
    setState(() {
      _loaded = true;
      _error = result.error;
      if (result.data != null) _data = result.data!;
    });

    final focus = _focusSosId;
    if (focus != null) {
      final sos = _data.sos.where((s) => s.id == focus).firstOrNull;
      if (sos != null && sos.hasPosition) {
        _focusSosId = null;
        _centered = true;
        _map.move(LatLng(sos.latitude!, sos.longitude!), 17);
        _openSos(sos);
      }
    }
  }

  // ------------------------------------------------------------- SOS sheet

  Future<void> _openSos(AssignedSos sos) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _SosSheet(
        sos: sos,
        onResolve: () => _resolve(sheetContext, sos),
        onDirections: () {
          Navigator.pop(sheetContext);
          _showDirections(sos);
        },
      ),
    );
  }

  Future<void> _resolve(BuildContext sheetContext, AssignedSos sos) async {
    var confirmed = false;
    await ConfirmModal.show(
      context: sheetContext,
      icon: Icons.check_circle_rounded,
      color: AppTheme.successGreen,
      title: 'Mark this SOS as resolved?',
      description:
          '${sos.residentName} will be told the emergency is over and asked to rate your response.',
      confirmText: 'Resolve',
      onConfirm: () => confirmed = true,
    );
    if (!confirmed) return;

    final error = await GobikerSos.instance.resolve(sos.id);
    if (!mounted) return;
    if (sheetContext.mounted) Navigator.pop(sheetContext);
    AppToast.show(
      context,
      error ?? 'SOS resolved. Thank you for responding!',
      type: error == null ? ToastType.success : ToastType.error,
    );
    _load();
  }

  // ---------------------------------------------------------------- build

  List<Marker> _markers() {
    final markers = <Marker>[];

    for (final g in _data.gobikers) {
      markers.add(
        _personMarker(
          g,
          icon: Icons.pedal_bike_rounded,
          color: gobikerColor(g.status),
          size: 36,
        ),
      );
    }

    final me = _me;
    if (me != null) {
      markers.add(
        Marker(
          point: LatLng(me.latitude, me.longitude),
          width: 26,
          height: 26,
          child: Semantics(
            label: 'You are here',
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A73E8),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 6),
                ],
              ),
            ),
          ),
        ),
      );
    }

    for (final s in _data.sos.where((s) => s.hasPosition)) {
      final color = sosColor(s.status);
      markers.add(
        Marker(
          point: LatLng(s.latitude!, s.longitude!),
          width: 52,
          height: 52,
          child: Semantics(
            button: true,
            label: 'SOS from ${s.residentName}, ${s.status}',
            child: GestureDetector(
              onTap: () => _openSos(s),
              child: Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Icon(
                    s.isOpen ? Icons.sos_rounded : Icons.check_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return markers;
  }

  Marker _personMarker(
    MapPerson p, {
    required IconData icon,
    required Color color,
    required double size,
  }) {
    return Marker(
      point: LatLng(p.latitude, p.longitude),
      width: size,
      height: size,
      child: Tooltip(
        message: p.name,
        triggerMode: TooltipTriggerMode.tap,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
          child: Icon(icon, color: Colors.white, size: size * 0.55),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = _me;
    final barangay = _data.barangay;
    final directions = _directionsSos;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live map'),
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
              initialCenter: me != null
                  ? LatLng(me.latitude, me.longitude)
                  : _fallbackCenter,
              initialZoom: me != null ? 16 : 13,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              // Satellite imagery: a GoBiker finds a house by its roof and the
              // road to it, not by a street name. Esri serves both the pictures
              // and the labels on top, so this stays one provider.
              TileLayer(
                urlTemplate:
                    'https://server.arcgisonline.com/ArcGIS/rest/services/'
                    'World_Imagery/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.rondago.app',
                maxZoom: 19,
              ),
              TileLayer(
                urlTemplate:
                    'https://server.arcgisonline.com/ArcGIS/rest/services/'
                    'Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.rondago.app',
                maxZoom: 19,
              ),
              if (directions != null && me != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [
                        LatLng(me.latitude, me.longitude),
                        LatLng(directions.latitude!, directions.longitude!),
                      ],
                      color: AppTheme.orange,
                      strokeWidth: 5,
                      borderColor: Colors.white,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              MarkerLayer(markers: _markers()),
              // The imagery credit has to stay readable: above the phone's gesture strip
              // (and above the directions bar when it is open), on the left so the
              // "center on me" button never covers it.
              Padding(
                padding: EdgeInsets.only(
                  bottom: bottomGap(context) + (directions != null ? 92 : 0),
                ),
                child: const SimpleAttributionWidget(
                  source: Text('Esri, Maxar, Earthstar Geographics'),
                  alignment: Alignment.bottomLeft,
                ),
              ),
            ],
          ),
          if (directions != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12 + bottomGap(context),
              child: _DirectionsBar(
                residentName: directions.residentName,
                distance: _distanceToSos,
                onRecenter: () => _fitToDirections(directions),
                onClose: () => setState(() => _directionsSosId = null),
              ),
            ),
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: _InfoBar(
              barangay: barangay,
              isGobiker: _isGobiker,
              data: _data,
              loaded: _loaded,
              error: _error,
            ),
          ),
        ],
      ),
      // Lifted above the imagery credit along the bottom, and above the directions bar.
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: extraBottomGap(context) + (directions != null ? 92 : 28),
        ),
        child: FloatingActionButton(
          tooltip: 'Center on me',
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: AppTheme.blue,
          onPressed: () => _locateMe(),
          child: const Icon(Icons.my_location_rounded),
        ),
      ),
    );
  }
}

/// The card on top of the map: barangay, who is online, the legend.
class _InfoBar extends StatelessWidget {
  const _InfoBar({
    required this.barangay,
    required this.isGobiker,
    required this.data,
    required this.loaded,
    required this.error,
  });

  final String? barangay;
  final bool isGobiker;
  final LiveMapData data;
  final bool loaded;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75);

    final String summary;
    if (!loaded) {
      summary = 'Loading the live map…';
    } else if (error != null) {
      summary = error!;
    } else if (barangay == null) {
      summary = 'Set your barangay in your profile to see who is nearby.';
    } else {
      final gobikers = data.gobikers.length;
      final open = data.sos.where((s) => s.isOpen).length;
      final parts = [
        '$gobikers GoBiker${gobikers == 1 ? '' : 's'} online',
        if (isGobiker && open > 0) '$open SOS assigned to you',
      ];
      summary = parts.join(' · ');
    }

    Widget legend(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );

    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(16),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              barangay == null ? 'Live map' : 'Barangay $barangay',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              summary,
              style: theme.textTheme.bodySmall?.copyWith(
                color: error != null ? AppTheme.errorRed : muted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                legend(const Color(0xFF1A73E8), 'You'),
                legend(AppTheme.blue, 'GoBiker'),
                legend(AppTheme.orange, 'Responding'),
                if (isGobiker) ...[
                  legend(sosYellow, 'SOS responding'),
                  legend(sosGreen, 'SOS resolved'),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "2.4 km to Ana Reyes", under the map, while the way there is shown.
class _DirectionsBar extends StatelessWidget {
  const _DirectionsBar({
    required this.residentName,
    required this.distance,
    required this.onRecenter,
    required this.onClose,
  });

  final String residentName;
  final String? distance;
  final VoidCallback onRecenter;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(14),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: [
            const Icon(Icons.directions_rounded, color: AppTheme.orange),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                distance == null
                    ? 'Finding your position…'
                    : '$distance to $residentName',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Fit both on screen',
              onPressed: onRecenter,
              icon: const Icon(Icons.fit_screen_rounded),
            ),
            IconButton(
              tooltip: 'Hide the way there',
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

/// Details of an assigned SOS: call, directions, resolve.
class _SosSheet extends StatelessWidget {
  const _SosSheet({
    required this.sos,
    required this.onResolve,
    required this.onDirections,
  });

  final AssignedSos sos;
  final VoidCallback onResolve;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = sosColor(sos.status);
    final label = switch (sos.status) {
      'responding' => 'Responding',
      'resolved' => 'Resolved',
      _ => 'Waiting',
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sos_rounded, color: color, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    sos.residentName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: sos.status == 'responding'
                          ? const Color(0xFF8A6A00)
                          : color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (sos.place.isNotEmpty)
              _line(theme, Icons.place_outlined, sos.place),
            if (sos.description != null)
              _line(theme, Icons.notes_rounded, sos.description!),
            if (sos.createdAt != null)
              _line(
                theme,
                Icons.schedule_rounded,
                'Sent ${DateFormat('h:mm a').format(sos.createdAt!)}',
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (sos.mobile != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          launchUrl(Uri(scheme: 'tel', path: sos.mobile)),
                      icon: const Icon(Icons.call_rounded),
                      label: const Text('Call'),
                    ),
                  ),
                if (sos.mobile != null && sos.hasPosition)
                  const SizedBox(width: 10),
                if (sos.hasPosition)
                  Expanded(
                    child: OutlinedButton.icon(
                      // Stays on this map: a GoBiker on a call should not be
                      // handed off to another app to find the way.
                      onPressed: onDirections,
                      icon: const Icon(Icons.directions_rounded),
                      label: const Text('Directions'),
                    ),
                  ),
              ],
            ),
            if (sos.isOpen) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.successGreen,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: onResolve,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Resolve'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _line(ThemeData theme, IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.hintColor),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
