import 'package:flutter/material.dart';

import '../screens/patient/app_colors.dart';
import '../screens/patient/ui_kit.dart';

/// What the resident chose on the night notice.
enum NightSosChoice { call911, sendAnyway }

/// Shown after the SOS hold at night, before the form: help from Go Bike may be slower,
/// so 911 is offered first. Null when they closed it without choosing (nothing happens).
Future<NightSosChoice?> showNightSosNotice(BuildContext context) {
  return showDialog<NightSosChoice>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: context.pal.card,
      icon: Icon(Icons.nightlight_round, color: context.pal.brand, size: 32),
      title: const Text("It's late at night", textAlign: TextAlign.center),
      content: Text(
        'Help from Go Bike may take longer at this hour, as fewer GoBikers '
        "are out. If someone's life is in danger, call 911 or your local "
        'hotline now.',
        style: T.body.copyWith(color: context.pal.ink),
        textAlign: TextAlign.center,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.xl),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PrimaryButton(
              label: 'Call 911',
              icon: Icons.call_rounded,
              danger: true,
              onPressed: () => Navigator.pop(context, NightSosChoice.call911),
            ),
            const SizedBox(height: Sp.sm),
            SecondaryButton(
              label: 'Send SOS anyway',
              onPressed: () =>
                  Navigator.pop(context, NightSosChoice.sendAnyway),
            ),
          ],
        ),
      ],
    ),
  );
}
