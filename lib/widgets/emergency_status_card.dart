import 'package:flutter/material.dart';

import '../core/emergency_watcher.dart';
import '../core/theme.dart';

/// Shows where the GoBiker's emergency stands. Nothing is shown when no
/// emergency was sent. Used on the dashboard and the active ronda screen.
class EmergencyStatusCard extends StatelessWidget {
  const EmergencyStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: EmergencyWatcher.instance,
      builder: (context, _) {
        final phase = EmergencyWatcher.instance.phase;
        if (phase == EmergencyPhase.none) return const SizedBox.shrink();

        final (color, icon, title, body) = switch (phase) {
          EmergencyPhase.waiting => (
            AppTheme.orange,
            Icons.hourglass_top_rounded,
            'Emergency alert sent',
            'Waiting for the admin to respond. Call 911 if it is urgent.',
          ),
          EmergencyPhase.responding => (
            AppTheme.blue,
            Icons.support_agent_rounded,
            'The admin is responding',
            'Your alert was received. Stay safe and keep your phone with you.',
          ),
          _ => (
            AppTheme.successGreen,
            Icons.check_circle_rounded,
            'Emergency resolved',
            'The admin marked your emergency as resolved.',
          ),
        };
        final muted = Theme.of(context).colorScheme.onSurface
            .withValues(alpha: 0.7);

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(body, style: TextStyle(fontSize: 13, color: muted)),
                    ],
                  ),
                ),
                if (phase == EmergencyPhase.resolved)
                  IconButton(
                    tooltip: 'Dismiss',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: EmergencyWatcher.instance.dismissResolved,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
