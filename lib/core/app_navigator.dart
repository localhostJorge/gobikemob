import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import 'emergency_watcher.dart';
import 'theme.dart';

/// The app's root navigator. It lets the app show an alert on top of whatever
/// screen the GoBiker is on, e.g. when the admin answers an emergency.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// How long the phone vibrates when the admin answers an emergency.
const Duration emergencyVibration = Duration(seconds: 1);

/// Vibrates for [emergencyVibration]. Replaced in tests.
Future<void> Function() vibratePhone = () async {
  try {
    if (await Vibration.hasVibrator()) {
      await Vibration.vibrate(duration: emergencyVibration.inMilliseconds);
      return;
    }
  } catch (_) {
    // Fall through to the short tap below.
  }
  await HapticFeedback.heavyImpact();
};

/// Pops up "The admin saw your alert" / "Emergency resolved" with a vibration.
/// Hooked up in `main.dart`.
void showEmergencyAlert(EmergencyPhase phase) {
  final context = appNavigatorKey.currentContext;
  if (context == null) return;

  final responding = phase == EmergencyPhase.responding;
  if (!responding && phase != EmergencyPhase.resolved) return;

  vibratePhone();
  SystemSound.play(SystemSoundType.alert);

  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(
        responding ? Icons.support_agent_rounded : Icons.check_circle_rounded,
        color: responding ? AppTheme.blue : AppTheme.successGreen,
        size: 40,
      ),
      title: Text(
        responding ? 'The admin saw your alert' : 'Emergency resolved',
        textAlign: TextAlign.center,
      ),
      content: Text(
        responding
            ? 'The admin received your emergency alert and is handling it. '
                  'Stay safe and keep your phone with you. '
                  'Call 911 if you need help right now.'
            : 'The admin marked your emergency as resolved.',
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
