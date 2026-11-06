import 'package:flutter/material.dart';

import '../../core/appointments.dart';
import 'app_colors.dart';
import 'ui_kit.dart';
import 'visit_record.dart' show formatDate;

/// The icon, colour and one-line explanation of a home-visit request's status.
({IconData icon, Color color, String help}) visitStatusStyle(
  Appointment a,
  AppPalette pal,
) => switch (a.status) {
  'accepted' => (
    icon: Icons.directions_bike_rounded,
    color: AppColors.blue,
    help:
        '${a.gobikerName ?? 'A GoBiker'} will visit you. They can also call you for confirmation or something else.',
  ),
  'completed' => (
    icon: Icons.check_circle_rounded,
    color: pal.greenText,
    help: 'Your visit is done. The check-up is in your Medical History.',
  ),
  'declined' => (
    icon: Icons.block_rounded,
    color: pal.muted,
    help:
        a.declineNote ??
        'This visit could not be scheduled. You can ask another GoBiker.',
  ),
  'cancelled' => (
    icon: Icons.cancel_outlined,
    color: pal.muted,
    help: 'You cancelled this request.',
  ),
  _ => (
    icon: Icons.schedule_rounded,
    color: pal.orangeText,
    help: a.gobikerName == null
        ? 'Waiting for a GoBiker in your barangay to accept it.'
        : 'Waiting for ${a.gobikerName} to accept. You will get a notification.',
  ),
};

/// One line of a request's details: an icon and the text.
class VisitFactRow extends StatelessWidget {
  const VisitFactRow(this.icon, this.text, {super.key});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Sp.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: context.pal.muted),
        const SizedBox(width: Sp.md),
        Expanded(child: Text(text, style: T.body)),
      ],
    ),
  );
}

/// A home-visit request: how it stands, what was asked, and (while it is open) a way to cancel it.
class VisitRequestCard extends StatelessWidget {
  const VisitRequestCard({
    super.key,
    required this.appointment,
    this.cancelling = false,
    this.onCancel,
  });

  final Appointment appointment;
  final bool cancelling;

  /// Offered only while the request is open.
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final s = visitStatusStyle(a, context.pal);
    final declined = a.status == 'declined';

    return Semantics(
      container: true,
      liveRegion: true,
      child: AppCard(
        borderColor: s.color.withValues(alpha: 0.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(s.icon, color: s.color, size: 22),
                const SizedBox(width: Sp.sm),
                Expanded(
                  child: Text(
                    a.statusLabel,
                    style: T.heading.copyWith(color: s.color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Sp.sm),
            // What the GoBiker wrote, said as theirs.
            if (declined)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.xs),
                child: Text(
                  a.gobikerName == null
                      ? 'Message'
                      : 'Message from ${a.gobikerName}',
                  style: T.label.muted(context),
                ),
              ),
            Text(s.help, style: T.body),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Sp.lg),
              child: Divider(height: 1, color: context.pal.divider),
            ),
            VisitFactRow(
              Icons.event_rounded,
              '${formatDate(a.preferredDate)} · ${a.windowLabel}',
            ),
            if (a.gobikerName != null)
              VisitFactRow(
                Icons.directions_bike_rounded,
                a.gobikerBarangay == null
                    ? a.gobikerName!
                    : '${a.gobikerName} · ${a.gobikerBarangay}',
              ),
            VisitFactRow(Icons.home_outlined, '${a.address}, ${a.barangay}'),
            VisitFactRow(Icons.notes_rounded, a.reason),
            if (onCancel != null && a.isOpen) ...[
              const SizedBox(height: Sp.lg),
              SecondaryButton(
                label: 'Cancel request',
                destructive: true,
                loading: cancelling,
                onPressed: onCancel,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Asks first, then cancels [a] and says so. True when it was cancelled.
Future<bool> cancelVisitRequest(BuildContext context, Appointment a) async {
  final ok = await showConfirm(
    context,
    title: 'Cancel this request?',
    message: a.gobikerName == null
        ? 'Your request will be withdrawn.'
        : '${a.gobikerName} will be told not to come.',
    confirmLabel: 'Cancel request',
    cancelLabel: 'Keep it',
    destructive: true,
  );
  if (!ok || !context.mounted) return false;

  final error = await ResidentAppointments.instance.cancel(a.id);
  if (!context.mounted) return error == null;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(error ?? 'Visit request cancelled.')),
    );
  return error == null;
}
