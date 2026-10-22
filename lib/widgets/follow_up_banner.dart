import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/follow_up.dart';
import '../core/theme.dart';

/// Shows the admin's decision about a patient, with the admin's note.
class FollowUpBanner extends StatelessWidget {
  const FollowUpBanner({super.key, required this.followUp});

  final FollowUp followUp;

  @override
  Widget build(BuildContext context) {
    final stop = followUp.isStop;
    final color = stop ? AppTheme.successGreen : AppTheme.blue;
    final muted = Theme.of(context).colorScheme.onSurface
        .withValues(alpha: 0.7);
    final decided = followUp.decidedAt == null
        ? null
        : DateFormat('MMM d, yyyy').format(followUp.decidedAt!);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            stop
                ? Icons.check_circle_outline_rounded
                : Icons.monitor_heart_outlined,
            color: color,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stop
                      ? 'No need for regular check-ups'
                      : 'Keep checking this patient',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stop
                      ? 'The admin decided this patient no longer needs to be checked every ronda.'
                      : 'The admin asked to keep checking this patient on your rondas.',
                  style: TextStyle(fontSize: 13, color: muted),
                ),
                if (followUp.note != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '“${followUp.note}”',
                    style: const TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (decided != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Decided $decided',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small tag for lists: "Stop checking" or "Keep checking".
class FollowUpChip extends StatelessWidget {
  const FollowUpChip({super.key, required this.followUp});

  final FollowUp followUp;

  @override
  Widget build(BuildContext context) {
    final color = followUp.isStop ? AppTheme.successGreen : AppTheme.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        followUp.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
