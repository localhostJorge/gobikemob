import 'package:flutter/material.dart';

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
      description: 'This immediately alerts the RHU admin with your current location. Use only for real emergencies.',
      confirmText: 'Send Alert',
      onConfirm: () {},
    );
    if (confirmed != true || !context.mounted) return;

    AppToast.show(context, 'Sending alert...', type: ToastType.info);

    final error = await TrackingService.instance.sendEmergency();
    if (!context.mounted) return;

    if (error != null) {
      AppToast.show(context, error, type: ToastType.error);
      return;
    }
    AppToast.show(context, 'Emergency alert sent', type: ToastType.success);
  }
}
