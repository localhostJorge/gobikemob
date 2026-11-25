import 'package:flutter/material.dart';

import '../core/emergency_watcher.dart';
import '../core/theme.dart';
import '../screens/patient/app_colors.dart';
import '../screens/patient/safety_tab.dart' show SosRequestCard;

/// Shows where the GoBiker's emergency stands. Nothing is shown when no
/// emergency was sent. Used on the dashboard and the active ronda screen.
///
/// When the server sends the emergency itself, it is the resident's SOS card:
/// who is on the way, their position on a map, and "Cancel emergency".
class EmergencyStatusCard extends StatelessWidget {
  const EmergencyStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: EmergencyWatcher.instance,
      builder: (context, _) {
        final phase = EmergencyWatcher.instance.phase;
        if (phase == EmergencyPhase.none) return const SizedBox.shrink();

        final sos = EmergencyWatcher.instance.current;
        if (sos != null) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (phase == EmergencyPhase.resolved)
                  IconButton(
                    tooltip: 'Dismiss',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: EmergencyWatcher.instance.dismissResolved,
                  ),
                SosRequestCard(
                  // A new id is a new emergency: start the card afresh.
                  key: ValueKey(sos.id),
                  sos: sos,
                  title: 'Your emergency',
                  noun: 'emergency',
                  onCancel: EmergencyWatcher.instance.cancel,
                  trackingPath: '/gobiker/emergency/${sos.id}/tracking',
                ),
              ],
            ),
          );
        }

        final (color, icon, title, body) = switch (phase) {
          EmergencyPhase.waiting => (
            AppTheme.orange,
            Icons.hourglass_top_rounded,
            'Emergency alert sent',
            'Waiting for the admin to see it. Call 911 if it is urgent.',
          ),
          EmergencyPhase.responding => (
            AppTheme.blue,
            Icons.support_agent_rounded,
            'The admin saw your alert',
            'The admin is handling it. Stay safe, keep your phone with you, and call 911 if you need help right now.',
          ),
          _ => (
            AppTheme.successGreen,
            Icons.check_circle_rounded,
            'Emergency resolved',
            'The admin marked your emergency as resolved.',
          ),
        };
        final muted = context.pal.muted;
        // The fill tints with the status color; words and icon use its readable shade.
        final ink = context.pal.tone(color);

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
                Icon(icon, color: ink, size: 28),
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
                          color: ink,
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
