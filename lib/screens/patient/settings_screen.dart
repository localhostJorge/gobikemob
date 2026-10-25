import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_colors.dart';
import 'notification_settings_screen.dart';
import 'patient_store.dart';
import 'skeletons.dart';
import 'ui_kit.dart';

/// Content of the Settings tab in the resident dashboard.
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PatientStore.instance,
      builder: (context, _) {
        final store = PatientStore.instance;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TabHeader('Settings'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Sp.gutter,
                  Sp.sm,
                  Sp.gutter,
                  Sp.xl,
                ),
                children: [
                  const SectionHeader('Notifications'),
                  CardGroup(
                    children: [
                      NavRow(
                        icon: Icons.notifications_none_rounded,
                        title: 'Notification settings',
                        subtitle: 'Choose which alerts you receive',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationSettingsScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Sp.xl),
                  const SectionHeader('Emergency SOS'),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Hold time', style: T.rowTitle),
                        const SizedBox(height: 2),
                        const Text(
                          'How long you hold the SOS button before it sends. '
                          'A longer hold avoids sending one by accident.',
                          style: T.secondary,
                        ),
                        const SizedBox(height: Sp.lg),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<int>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(value: 1, label: Text('1 sec')),
                              ButtonSegment(value: 2, label: Text('2 sec')),
                              ButtonSegment(value: 3, label: Text('3 sec')),
                            ],
                            selected: {store.sosHoldSeconds},
                            onSelectionChanged: (s) =>
                                store.setSosHold(s.first),
                            style: SegmentedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              textStyle: T.label.copyWith(
                                fontFamily: kFontFamily,
                              ),
                              side: const BorderSide(color: AppColors.line),
                              selectedBackgroundColor: AppColors.textDark,
                              selectedForegroundColor: Colors.white,
                              foregroundColor: AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Sp.xl),
                  const SectionHeader('About'),
                  CardGroup(
                    children: [
                      FutureBuilder<PackageInfo>(
                        future: PackageInfo.fromPlatform(),
                        builder: (context, snap) => NavRow(
                          icon: Icons.info_outline_rounded,
                          title: 'RondaGo',
                          subtitle: snap.hasData
                              ? 'Version ${snap.data!.version}'
                              : null,
                          subtitleWidget: snap.hasData
                              ? null
                              : const LineSkeleton(width: 80),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
