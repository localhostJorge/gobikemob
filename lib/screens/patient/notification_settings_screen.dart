import 'package:flutter/material.dart';

import '../../core/push_service.dart';
import 'app_colors.dart';
import 'patient_store.dart';
import 'patient_ui.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: patientAppBar(context, 'Notification Settings'),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: PatientStore.instance,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _group('Alerts', const [
                  _Toggle(
                    keyName: 'sos_updates',
                    title: 'SOS request updates',
                    subtitle: 'When a responder receives or answers your SOS',
                  ),
                  _Toggle(
                    keyName: 'appointments',
                    title: 'Appointment reminders',
                    subtitle: 'Status changes and upcoming appointments',
                  ),
                  _Toggle(
                    keyName: 'checkups',
                    title: 'Check-up results',
                    subtitle: 'When a GoBiker records or updates your check-up',
                  ),
                ]),
                const SizedBox(height: 16),
                _group('Alert style', const [
                  _Toggle(
                    keyName: 'sound',
                    title: 'Sound',
                    subtitle: 'Play a sound for new alerts',
                  ),
                  _Toggle(
                    keyName: 'vibration',
                    title: 'Vibration',
                    subtitle: 'Vibrate for new alerts',
                  ),
                ]),
                const SizedBox(height: 16),
                const _PhoneStatus(),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Notifications arrive even when RondaGo is closed. If none '
                    'arrive, check that notifications are allowed for RondaGo '
                    "in your phone's settings.",
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _group(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
            ),
          ),
        ),
        Container(
          decoration: cardDecoration(),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _Toggle extends StatelessWidget {
  final String keyName;
  final String title;
  final String subtitle;

  const _Toggle({
    required this.keyName,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final store = PatientStore.instance;
    return SwitchListTile(
      value: store.toggle(keyName),
      onChanged: (v) async {
        final error = await store.setToggle(keyName, v);
        if (error != null && context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text("Couldn't save: $error")));
        }
      },
      activeTrackColor: AppColors.red,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
    );
  }
}

/// Whether this phone is set up to receive notifications, with a retry when
/// it isn't (so testers can see at a glance why nothing arrives).
class _PhoneStatus extends StatelessWidget {
  const _PhoneStatus();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PushStatus>(
      valueListenable: PushService.instance.status,
      builder: (context, status, _) {
        final (icon, color, text) = switch (status.state) {
          'registered' => (
            Icons.check_circle_rounded,
            const Color(0xFF2E9E5B),
            'This phone receives your notifications.',
          ),
          'working' => (
            Icons.sync_rounded,
            AppColors.textMuted,
            'Setting up notifications on this phone…',
          ),
          'failed' => (
            Icons.error_outline_rounded,
            AppColors.red,
            status.message ?? 'Notifications are not set up on this phone.',
          ),
          _ => (
            Icons.help_outline_rounded,
            AppColors.textMuted,
            'Not checked yet on this phone.',
          ),
        };
        final canRetry = status.state == 'failed' || status.state == 'unknown';

        return Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
            decoration: cardDecoration(14),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color == AppColors.textMuted
                          ? AppColors.textDark
                          : color,
                    ),
                  ),
                ),
                if (canRetry)
                  TextButton(
                    onPressed: PushService.instance.registerDevice,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.red,
                      minimumSize: const Size(48, 48),
                    ),
                    child: const Text('Try again'),
                  )
                else
                  const SizedBox(height: 48),
              ],
            ),
          ),
        );
      },
    );
  }
}
