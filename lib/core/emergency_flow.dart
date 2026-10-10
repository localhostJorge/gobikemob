import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/app_toast.dart';
import '../widgets/confirm_modal.dart';
import 'theme.dart';
import 'tracking_service.dart';

enum _FailAction { cancel, retry, call }

/// One emergency flow, used by the dashboard and the active ronda screen.
/// Confirm -> get GPS -> send to the Laravel API -> show the real result.
class EmergencyFlow {
  EmergencyFlow._();

  static bool _running = false;

  static Future<void> run(BuildContext context) async {
    if (_running) return;
    _running = true;
    try {
      final confirmed = await ConfirmModal.show(
        context: context,
        icon: Icons.warning_amber_rounded,
        color: AppTheme.errorRed,
        title: 'Send emergency alert?',
        description: 'This sends your current location to the admin. Use only for real emergencies.',
        confirmText: 'Send Alert',
        onConfirm: () {},
      );
      if (confirmed != true || !context.mounted) return;
      await _sendAndReport(context);
    } finally {
      _running = false;
    }
  }

  static Future<void> _sendAndReport(BuildContext context) async {
    final navigator = Navigator.of(context, rootNavigator: true);

    while (true) {
      _showSending(context);
      final result = await TrackingService.instance.sendEmergencyAlert();
      navigator.pop(); // close the "Sending..." dialog
      if (!context.mounted) return;

      if (result.ok) {
        AppToast.show(
          context,
          'Emergency alert sent to the admin.',
          type: ToastType.success,
        );
        final call = await _sentDialog(context);
        if (call == true && context.mounted) await _call911(context);
        return;
      }

      final action = await _failedDialog(context, result.message);
      if (!context.mounted) return;
      if (action == _FailAction.retry) continue;
      if (action == _FailAction.call) await _call911(context);
      return;
    }
  }

  static void _showSending(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Padding(
            padding: EdgeInsets.all(24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppTheme.errorRed,
                  ),
                ),
                SizedBox(width: 20),
                Flexible(
                  child: Text(
                    'Sending emergency alert...',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<bool?> _sentDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.check_circle_rounded,
          color: AppTheme.successGreen,
          size: 36,
        ),
        title: const Text('Alert sent'),
        content: const Text(
          'The admin can now notice you in the map.'
          'Do you want also call 911?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.call_rounded),
            label: const Text('Call 911'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  static Future<_FailAction?> _failedDialog(
    BuildContext context,
    String message,
  ) {
    return showDialog<_FailAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.error_outline_rounded,
          color: AppTheme.errorRed,
          size: 36,
        ),
        title: const Text('Alert not sent'),
        content: Text('$message\n\nIf this is urgent, call 911 now.'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_FailAction.cancel),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(_FailAction.retry),
            child: const Text('Try again'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(_FailAction.call),
            icon: const Icon(Icons.call_rounded),
            label: const Text('Call 911'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _call911(BuildContext context) async {
    try {
      final opened = await launchUrl(Uri(scheme: 'tel', path: '911'));
      if (!opened && context.mounted) {
        AppToast.show(
          context,
          "Couldn't open the phone dialer. Please dial 911 manually.",
          type: ToastType.error,
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      AppToast.show(
        context,
        "Couldn't open the phone dialer. Please dial 911 manually.",
        type: ToastType.error,
      );
    }
  }
}
