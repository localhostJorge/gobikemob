import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' show Geolocator;

import '../../core/push_service.dart';
import 'app_colors.dart';
import 'patient_store.dart';
import 'skeletons.dart';
import 'ui_kit.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: patientAppBar(context, 'Notification settings'),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: PatientStore.instance,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                Sp.gutter,
                Sp.sm,
                Sp.gutter,
                Sp.xl,
              ),
              children: [
                // First: does this phone receive them at all?
                const _PhoneStatus(),
                const SizedBox(height: Sp.xl),
                const SectionHeader('Tell me about'),
                const CardGroup(
                  children: [
                    _Toggle(
                      keyName: 'sos_updates',
                      title: 'SOS updates',
                      subtitle: 'When someone responds to your SOS',
                    ),
                    _Toggle(
                      keyName: 'appointments',
                      title: 'Home visits',
                      subtitle: 'When a request is accepted, declined or done',
                    ),
                    _Toggle(
                      keyName: 'checkups',
                      title: 'Check-ups',
                      subtitle: 'When a GoBiker records or updates yours',
                    ),
                  ],
                ),
                const SizedBox(height: Sp.xl),
                const SectionHeader('How it alerts'),
                const CardGroup(
                  children: [
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
                  ],
                ),
                const SizedBox(height: Sp.lg),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Notifications arrive even when RondaGo is closed. If none '
                    'arrive, check that notifications are allowed for RondaGo '
                    "in your phone's settings.",
                    style: T.meta,
                  ),
                ),
              ],
            );
          },
        ),
      ),
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
    // Listens itself: the toggles are const, so the screen's rebuild skips
    // them and the switch would only move after reopening the screen.
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => SwitchListTile(
        value: store.toggle(keyName),
        onChanged: (v) async {
          final error = await store.setToggle(keyName, v);
          if (error != null && context.mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text("Couldn't save: $error")));
          }
        },
        contentPadding: const EdgeInsets.fromLTRB(Sp.lg, 4, Sp.md, 4),
        activeTrackColor: AppColors.textDark,
        activeThumbColor: Colors.white,
        title: Text(title, style: T.rowTitle),
        subtitle: Text(subtitle, style: T.secondary),
      ),
    );
  }
}

/// Whether this phone is set up to receive notifications, with a retry when
/// it isn't (so testers can see at a glance why nothing arrives).
class _PhoneStatus extends StatefulWidget {
  const _PhoneStatus();

  @override
  State<_PhoneStatus> createState() => _PhoneStatusState();
}

class _PhoneStatusState extends State<_PhoneStatus>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // A failure at app start (e.g. while the location prompt was open) is
    // often gone by now: check again instead of showing an old error.
    _recheck();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from the phone's settings (maybe after allowing notifications).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _recheck();
  }

  void _recheck() {
    final state = PushService.instance.status.value.state;
    if (state != 'registered' && state != 'working') {
      PushService.instance.registerDevice();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PushStatus>(
      valueListenable: PushService.instance.status,
      builder: (context, status, _) {
        final (icon, color, text) = switch (status.state) {
          'registered' => (
            Icons.check_circle_rounded,
            AppColors.greenText,
            'This phone receives your notifications.',
          ),
          'working' => (
            Icons.sync_rounded,
            AppColors.textMuted,
            'Setting up notifications on this phone…',
          ),
          'blocked' => (
            Icons.notifications_off_outlined,
            AppColors.redText,
            "Notifications are turned off for RondaGo in your phone's settings.",
          ),
          'failed' => (
            Icons.error_outline_rounded,
            AppColors.redText,
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
            padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.xs, Sp.xs, Sp.xs),
            decoration: cardDecoration(),
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: Sp.md),
                Expanded(
                  child: status.state == 'working'
                      ? const LineSkeleton(width: 220)
                      : Text(
                          text,
                          style: T.label.copyWith(
                            color: color == AppColors.textMuted
                                ? AppColors.textDark
                                : color,
                          ),
                        ),
                ),
                if (status.state == 'blocked')
                  QuietButton(
                    label: 'Open settings',
                    color: AppColors.redText,
                    onPressed: Geolocator.openAppSettings,
                  )
                else if (canRetry)
                  QuietButton(
                    label: 'Try again',
                    color: AppColors.redText,
                    onPressed: PushService.instance.registerDevice,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
