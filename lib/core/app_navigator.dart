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

/// A longer, broken pattern for an emergency handed to this GoBiker: it has to
/// be felt through a pocket, out on the road.
const List<int> sosAssignedVibration = [0, 600, 250, 600, 250, 600];

/// Vibrates [sosAssignedVibration]. Replaced in tests.
Future<void> Function() vibrateUrgently = () async {
  try {
    if (await Vibration.hasVibrator()) {
      await Vibration.vibrate(pattern: sosAssignedVibration);
      return;
    }
  } catch (_) {
    // Fall through to the short tap below.
  }
  await HapticFeedback.heavyImpact();
};

/// The admin sent this GoBiker to a resident's emergency: vibrate and say so on
/// top of whatever screen they are on, with a button that opens the map on it.
///
/// Returns true once they accept it. Shown only while the app is open; with
/// the app closed the notification itself opens the same map.
Future<bool> showSosAssignedAlert({
  required String residentName,
  required String place,
}) async {
  final context = appNavigatorKey.currentContext;
  if (context == null) return false;

  vibrateUrgently();
  SystemSound.play(SystemSoundType.alert);

  final view = await showDialog<bool>(
    context: context,
    // Unskippable: someone is waiting for help. It cannot be tapped away or
    // dismissed with the back button, only accepted.
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: AlertDialog(
        icon: const Icon(Icons.sos_rounded, color: AppTheme.errorRed, size: 40),
        title: const Text(
          'Emergency assigned to you',
          textAlign: TextAlign.center,
        ),
        content: Text(
          place.isEmpty
              ? '$residentName needs help. You are the GoBiker sent to respond.'
              : '$residentName needs help at $place. You are the GoBiker sent to respond.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        // One way out of this: take it. There is no "Later" for an emergency
        // the admin has already sent this GoBiker to.
        actions: [
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.map_rounded),
            label: const Text('Accept'),
          ),
        ],
      ),
    ),
  );

  return view ?? false;
}

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
