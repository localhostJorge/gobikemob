import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'notification_settings_screen.dart';
import 'patient_store.dart';
import 'patient_ui.dart';

/// Content of the Settings tab in the resident dashboard.
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  Future<void> _clearHistory(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear activity history?'),
        content: const Text(
          'This removes your SOS and appointment entries from History on '
          'this device. Your medical check-up records are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear',
                style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await PatientStore.instance.clearActivities();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Activity history cleared')));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PatientStore.instance,
      builder: (context, _) {
        final store = PatientStore.instance;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text('Settings',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark)),
            ),
            _label('Notifications'),
            _card([
              _NavTile(
                icon: Icons.notifications_none_rounded,
                title: 'Notification Settings',
                subtitle: 'Choose which alerts you receive',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationSettingsScreen(),
                  ),
                ),
              ),
            ]),
            _label('Emergency SOS'),
            _card([
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Hold time',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark)),
                    const SizedBox(height: 2),
                    const Text(
                      'How long you press and hold the SOS button before it '
                      'activates. Longer holds prevent accidental alerts.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<int>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: 2, label: Text('2 sec')),
                          ButtonSegment(value: 3, label: Text('3 sec')),
                          ButtonSegment(value: 5, label: Text('5 sec')),
                        ],
                        selected: {store.sosHoldSeconds},
                        onSelectionChanged: (s) => store.setSosHold(s.first),
                        style: SegmentedButton.styleFrom(
                          selectedBackgroundColor: AppColors.redSoft,
                          selectedForegroundColor: AppColors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
            _label('Data'),
            _card([
              _NavTile(
                icon: Icons.delete_sweep_outlined,
                title: 'Clear activity history',
                subtitle: 'Remove SOS and appointment entries from History',
                onTap: () => _clearHistory(context),
              ),
            ]),
            _label('About'),
            _card([
              const _NavTile(
                icon: Icons.info_outline_rounded,
                title: 'GoBike',
                subtitle: 'Version 1.0.0',
              ),
            ]),
          ],
        );
      },
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted)),
      );

  Widget _card(List<Widget> children) => Container(
        decoration: cardDecoration(),
        child: Column(children: children),
      );
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.redSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.red, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark)),
      subtitle: Text(subtitle,
          style:
              const TextStyle(fontSize: 12, color: AppColors.textMuted)),
      trailing: onTap == null
          ? null
          : const Icon(Icons.chevron_right, color: AppColors.textMuted),
    );
  }
}