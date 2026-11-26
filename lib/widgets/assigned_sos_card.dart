import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/live_map.dart';
import '../screens/live_map_screen.dart' show formatDistance, sosRed;
import '../screens/patient/app_colors.dart';
import '../screens/patient/ui_kit.dart';
import 'sos_severity.dart';

/// An SOS the admin sent this GoBiker to, on Home.
///
/// Reads top to bottom the way a GoBiker needs it: who, where, what
/// happened, how far. Then one row of actions that never wrap: call,
/// Directions (the main one) and Resolve. Decline sits apart underneath, so
/// it is not hit by accident on a moving bike.
class AssignedSosCard extends StatelessWidget {
  const AssignedSosCard({
    super.key,
    required this.sos,
    required this.onDirections,
    required this.onResolve,
    required this.onDecline,
    this.from,
    this.now,
  });

  final AssignedSos sos;
  final VoidCallback onDirections;
  final VoidCallback onResolve;
  final VoidCallback onDecline;

  /// Where the GoBiker is, for "3.2 km away". Left out when unknown.
  final LatLng? from;

  /// The clock "6 min ago" counts from (for tests); the real time when null.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final away = _away();
    final ago = _ago();

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md + 2, Sp.lg, Sp.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: sosRed,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: Sp.sm),
                    Expanded(
                      child: Text(
                        sos.fromGobiker
                            ? 'GoBiker emergency · Responding'
                            : 'SOS · Responding',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.meta.copyWith(
                          color: pal.redText,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    if (ago != null)
                      Text(ago, style: T.meta.copyWith(color: pal.muted)),
                  ],
                ),
                const SizedBox(height: Sp.sm),
                Text(
                  sos.residentName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: T.heading.copyWith(color: pal.heading),
                ),
                // How bad it is, as the resident judged it: hidden when they were not asked.
                if (sos.severity != null && sos.severityLabel != null ||
                    sos.injuredLabel != null) ...[
                  const SizedBox(height: Sp.sm),
                  Wrap(
                    spacing: Sp.sm,
                    runSpacing: Sp.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (sos.severity != null && sos.severityLabel != null)
                        SosSeverityChip(
                          severity: sos.severity!,
                          label: sos.severityLabel!,
                        ),
                      if (sos.injuredLabel != null)
                        Text(
                          'Injured people: ${sos.injuredLabel}',
                          style: T.meta.copyWith(
                            color: sos.injured == 'yes' ? pal.redText : pal.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ],
                if (sos.place.isNotEmpty) ...[
                  const SizedBox(height: Sp.xs),
                  Text(
                    sos.place,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: T.secondary.copyWith(color: pal.muted),
                  ),
                ],
                if (sos.description != null) ...[
                  const SizedBox(height: Sp.sm),
                  Text(
                    sos.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: T.body.copyWith(color: pal.ink),
                  ),
                ],
                if (away != null) ...[
                  const SizedBox(height: Sp.sm),
                  Text(away, style: T.meta.copyWith(color: pal.muted)),
                ],
                if (sos.otherResponders.isNotEmpty) ...[
                  const SizedBox(height: Sp.sm),
                  Text(
                    'Also responding: ${sos.otherResponders.join(', ')}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: T.meta.copyWith(color: pal.ink),
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: pal.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, 0),
            child: Row(
              children: [
                if (sos.mobile != null) ...[
                  _CallButton(mobile: sos.mobile!, name: sos.residentName),
                  const SizedBox(width: Sp.sm),
                ],
                Expanded(
                  flex: 3,
                  child: _ActionButton(
                    label: 'Directions',
                    filled: true,
                    color: AppColors.blue,
                    onPressed: sos.hasPosition ? onDirections : null,
                  ),
                ),
                const SizedBox(width: Sp.sm),
                Expanded(
                  flex: 2,
                  child: _ActionButton(
                    label: 'Resolve',
                    filled: false,
                    color: pal.greenText,
                    onPressed: onResolve,
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Sp.xs, 0, Sp.xs, Sp.xs),
              child: TextButton(
                onPressed: onDecline,
                style: TextButton.styleFrom(
                  foregroundColor: pal.redText,
                  minimumSize: const Size(48, 44),
                  padding: const EdgeInsets.symmetric(horizontal: Sp.sm),
                  textStyle: T.secondary.copyWith(
                    fontFamily: kFontFamily,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text(
                  "Can't respond? Decline",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _away() {
    final me = from;
    if (me == null || !sos.hasPosition) return null;
    final metres = const Distance().as(
      LengthUnit.Meter,
      me,
      LatLng(sos.latitude!, sos.longitude!),
    );
    return '${formatDistance(metres)} away';
  }

  String? _ago() {
    final sent = sos.createdAt;
    if (sent == null) return null;
    final minutes = (now ?? DateTime.now()).difference(sent).inMinutes;
    if (minutes < 1) return 'Just now';
    if (minutes < 60) return '$minutes min ago';
    final hours = minutes ~/ 60;
    return hours < 24 ? '$hours h ago' : '${hours ~/ 24} d ago';
  }
}

/// A 48 dp button whose label stays on one line, shrinking before it wraps.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.filled,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Rd.control),
    );
    const padding = EdgeInsets.symmetric(horizontal: Sp.sm);
    const size = Size(0, 48);
    final text = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(label, maxLines: 1, softWrap: false),
    );
    final textStyle = T.button.copyWith(fontSize: 15);

    if (filled) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: size,
          padding: padding,
          shape: shape,
          textStyle: textStyle,
        ),
        child: text,
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        minimumSize: size,
        padding: padding,
        shape: shape,
        textStyle: textStyle,
      ),
      child: text,
    );
  }
}

/// Calls the resident: a square 48 dp target, the phone icon alone.
class _CallButton extends StatelessWidget {
  const _CallButton({required this.mobile, required this.name});

  final String mobile;
  final String name;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return SizedBox.square(
      dimension: 48,
      child: OutlinedButton(
        onPressed: () => launchUrl(Uri(scheme: 'tel', path: mobile)),
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: pal.brand,
          side: BorderSide(color: pal.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Rd.control),
          ),
        ),
        child: Semantics(
          label: 'Call $name',
          child: const Icon(Icons.call_rounded, size: 22),
        ),
      ),
    );
  }
}
