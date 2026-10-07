import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/app_toast.dart';
import '../widgets/confirm_modal.dart';
import 'theme.dart';
import 'tracking_service.dart';

/// One emergency flow, used by the dashboard and the active ronda screen.
class EmergencyFlow {
  EmergencyFlow._();

  static Future<void> run(BuildContext context) async {
    final confirmed = await ConfirmModal.show(
      context: context,
      icon: Icons.warning_amber_rounded,
      color: AppTheme.errorRed,
      title: 'Send emergency alert?',
      description: 'This prepares an emergency alert with your current location. Use only for real emergencies.',
      confirmText: 'Send Alert',
      onConfirm: () {},
    );
    if (confirmed != true || !context.mounted) return;

    final error = await TrackingService.instance.prepareEmergencyLocation();
    if (!context.mounted) return;

    if (error != null) {
      AppToast.show(context, error, type: ToastType.error);
    } else {
      // TODO(api): send this captured location when the emergency endpoint is available.
      AppToast.show(context, 'Emergency alert sent', type: ToastType.success);
    }

    final callEmergency = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.call_rounded, color: AppTheme.errorRed),
        title: const Text('Need immediate help?'),
        content: const Text(
          'Emergency notifications to the admin are not connected yet. '
          'Call 911 for immediate assistance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.call_rounded),
            label: const Text('Call emergency number'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (callEmergency != true || !context.mounted) return;
    try {
      final opened = await launchUrl(Uri(scheme: 'tel', path: '911'));
      if (!opened && context.mounted) {
        AppToast.show(
          context,
          "Couldn't open the phone dialer. Please dial 911 manually.",
          type: ToastType.error,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      AppToast.show(
        context,
        "Couldn't open the phone dialer. Please dial 911 manually.",
        type: ToastType.error,
      );
    }
  }
}
