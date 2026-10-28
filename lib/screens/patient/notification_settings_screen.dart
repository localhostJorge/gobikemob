import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' show Geolocator;

import '../../core/push_service.dart';
import 'app_colors.dart';
import 'patient_store.dart';
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
                // Sets up notifications quietly; shows a notice only when
                // they are turned off in the phone's settings.
                const _PhoneStatus(),
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

/// Sets this phone up for notifications without showing anything (no loading,
/// no retry). Only when notifications are turned off for RondaGo in the
/// phone's settings does it show a notice with a way to turn them on.
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
        if (status.state != 'blocked') return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: Sp.xl),
          child: Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.xs, Sp.xs, Sp.xs),
              decoration: cardDecoration(),
              constraints: const BoxConstraints(minHeight: 56),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_off_outlined,
                    color: AppColors.redText,
                    size: 22,
                  ),
                  const SizedBox(width: Sp.md),
                  Expanded(
                    child: Text(
                      "Notifications are turned off for RondaGo in your phone's settings.",
                      style: T.label.copyWith(color: AppColors.redText),
                    ),
                  ),
                  const QuietButton(
                    label: 'Open settings',
                    color: AppColors.redText,
                    onPressed: Geolocator.openAppSettings,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
