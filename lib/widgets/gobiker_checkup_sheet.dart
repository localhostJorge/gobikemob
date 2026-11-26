import 'package:flutter/material.dart';

import '../core/appointments.dart';
import '../core/live_map.dart';
import '../screens/patient/app_colors.dart';
import '../screens/patient/ui_kit.dart';
import 'bottom_gap.dart';
import 'initials_avatar.dart';

/// What a resident sees after tapping a GoBiker on the live map: who it is, whether they
/// are on a ronda, and a button to ask them for a check-up (a home visit).
///
/// The button is held back when the GoBiker is busy with an emergency, when the resident
/// already asked this GoBiker (it then opens that request), or when the resident already
/// has [ResidentAppointments.maxOpen] requests open.
class GobikerCheckupSheet extends StatelessWidget {
  const GobikerCheckupSheet({
    super.key,
    required this.gobiker,
    required this.onRequest,
    required this.onViewRequest,
    this.openRequest,
    this.atLimit = false,
  });

  final MapPerson gobiker;

  /// The request this resident already has open with [gobiker], if any.
  final Appointment? openRequest;

  /// The resident has as many requests open as they may.
  final bool atLimit;

  final VoidCallback onRequest;
  final VoidCallback onViewRequest;

  /// "On ronda in Poblacion", "Online · Poblacion", or that they are busy.
  static String statusLine(MapPerson g) {
    if (g.isBusy) return 'Busy with an emergency right now';
    final where = g.barangay;
    if (g.onRonda) return where == null ? 'On ronda' : 'On ronda in $where';
    return where == null ? 'Online' : 'Online · $where';
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final busy = gobiker.isBusy;
    final asked = openRequest != null;

    final String? note = busy
        ? null
        : asked
        ? 'You already asked ${gobiker.name} for a check-up.'
        : atLimit
        ? 'You have ${ResidentAppointments.maxOpen} open requests. '
              'Cancel one or wait for a GoBiker to finish it.'
        : null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Sp.gutter,
        Sp.xl,
        Sp.gutter,
        Sp.lg + bottomGap(context),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InitialsAvatar(
                gobiker.name,
                imageUrl: gobiker.photoUrl,
                radius: 28,
              ),
              const SizedBox(width: Sp.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gobiker.name,
                      style: T.heading.copyWith(color: pal.heading),
                    ),
                    const SizedBox(height: Sp.xs),
                    Text(
                      statusLine(gobiker),
                      style: T.secondary.copyWith(
                        color: busy ? pal.redText : pal.muted,
                        fontWeight: busy ? FontWeight.w600 : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: Sp.lg),
            Text(note, style: T.secondary.copyWith(color: pal.ink)),
          ],
          const SizedBox(height: Sp.xl),
          if (asked && !busy)
            PrimaryButton(
              label: 'View request',
              icon: Icons.event_note_rounded,
              onPressed: onViewRequest,
            )
          else
            PrimaryButton(
              label: 'Request a check-up',
              icon: Icons.medical_services_rounded,
              onPressed: busy || atLimit ? null : onRequest,
            ),
        ],
      ),
    );
  }
}
