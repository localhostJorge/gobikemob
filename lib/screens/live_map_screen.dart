import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/auth_service.dart';
import '../core/live_map.dart';
import '../core/presence_service.dart';
import '../core/theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/confirm_modal.dart';

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

  bool get _isGobiker => AuthService.instance.currentUser?.isGoBiker ?? false;

  @override
  void initState() {
    super.initState();
    _focusSosId = widget.focusSosId;
    PresenceService.instance.latest.addListener(_onMyPosition);
    PresenceService.instance.sendNow();
    _locateMe(move: false);
    _load();
    _timer = Timer.periodic(_refresh, (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    PresenceService.instance.latest.removeListener(_onMyPosition);
    super.dispose();
  }

  Position? get _me => PresenceService.instance.latest.value;

  void _onMyPosition() {
    if (!mounted) return;
    setState(() {});
    if (!_centered && _me != null && _focusSosId == null) {
      _centered = true;
      _map.move(LatLng(_me!.latitude, _me!.longitude), 16);
    }
  }

  Future<void> _locateMe({bool move = true}) async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (move && mounted) {
          AppToast.show(
            context,
            'Allow location access to see yourself on the map.',
            type: ToastType.error,
          );
        }
        return;
      }
      final p =
          await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition();
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
      builder: (sheetContext) =>
          _SosSheet(sos: sos, onResolve: () => _resolve(sheetContext, sos)),
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
          color: g.status == 'active' ? AppTheme.orange : sosRed,
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
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.rondago.app',
                maxZoom: 19,
              ),
              MarkerLayer(markers: _markers()),
              const SimpleAttributionWidget(
                source: Text('OpenStreetMap contributors'),
              ),
            ],
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
      floatingActionButton: FloatingActionButton(
        tooltip: 'Center on me',
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: AppTheme.blue,
        onPressed: () => _locateMe(),
        child: const Icon(Icons.my_location_rounded),
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
                legend(AppTheme.orange, 'GoBiker'),
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

/// Details of an assigned SOS: call, directions, resolve.
class _SosSheet extends StatelessWidget {
  const _SosSheet({required this.sos, required this.onResolve});

  final AssignedSos sos;
  final VoidCallback onResolve;

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
                      onPressed: () => launchUrl(
                        Uri.parse(
                          'https://www.google.com/maps/dir/?api=1&destination=${sos.latitude},${sos.longitude}',
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
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
