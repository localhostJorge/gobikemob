import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/theme.dart';
import 'app_colors.dart';
import 'patient_store.dart';
import 'skeletons.dart';
import 'ui_kit.dart';

// The settings of the resident app. They live inside the Profile tab, so this file
// holds the pieces that tab puts together rather than a screen of its own.

/// The light / dark switch. The same setting the GoBiker profile panel changes, kept
/// on the phone, so it also applies the next time the app opens.
class DarkModeRow extends StatelessWidget {
  const DarkModeRow({super.key});

  @override
  Widget build(BuildContext context) {
    // Listens itself: the row is const, so the screen's rebuild skips it.
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) => SwitchListTile(
        value: Theme.of(context).brightness == Brightness.dark,
        onChanged: (on) => ThemeController.instance.setThemeMode(
          on ? ThemeMode.dark : ThemeMode.light,
        ),
        contentPadding: const EdgeInsets.fromLTRB(Sp.lg, 4, Sp.md, 4),
        activeTrackColor: context.pal.ink,
        activeThumbColor: context.pal.card,
        secondary: Icon(Icons.dark_mode_outlined, color: context.pal.muted),
        title: const Text('Dark mode', style: T.rowTitle),
        subtitle: Text(
          'Easier on the eyes at night',
          style: T.secondary.muted(context),
        ),
      ),
    );
  }
}

/// How long the SOS button must be held before it sends: 1, 2 or 3 seconds.
class SosHoldTimeCard extends StatelessWidget {
  const SosHoldTimeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PatientStore.instance,
      builder: (context, _) {
        final store = PatientStore.instance;
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Hold time', style: T.rowTitle),
              const SizedBox(height: 2),
              Text(
                'How long you hold the SOS button before it sends. '
                'A longer hold avoids sending one by accident.',
                style: T.secondary.muted(context),
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
                  onSelectionChanged: (s) => store.setSosHold(s.first),
                  style: SegmentedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    textStyle: T.label.copyWith(fontFamily: kFontFamily),
                    side: BorderSide(color: context.pal.line),
                    selectedBackgroundColor: context.pal.ink,
                    selectedForegroundColor: context.pal.card,
                    foregroundColor: context.pal.ink,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The app name and the installed version.
class AboutRow extends StatelessWidget {
  const AboutRow({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) => NavRow(
        icon: Icons.info_outline_rounded,
        title: 'RondaGo',
        subtitle: snap.hasData ? 'Version ${snap.data!.version}' : null,
        subtitleWidget: snap.hasData ? null : const LineSkeleton(width: 80),
      ),
    );
  }
}
