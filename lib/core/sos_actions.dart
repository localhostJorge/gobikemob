import 'package:flutter/material.dart';

import '../widgets/app_toast.dart';
import '../widgets/decline_reason_dialog.dart';
import 'live_map.dart';

/// Turns down the SOS [id] the admin sent this GoBiker to. A required reason
/// goes to the admin, who then sends someone else; the request leaves this
/// GoBiker's list. Used by the Home card and the "Emergency assigned to you"
/// alert.
///
/// Returns false when the GoBiker went back without declining, true once the
/// decline was sent (a toast says whether it went through).
Future<bool> declineAssignedSos(BuildContext context, int id) async {
  final name = GobikerSos.instance.open
      .where((s) => s.id == id)
      .firstOrNull
      ?.residentName;
  final reason = await showDeclineReasonDialog(
    context,
    title: 'Decline this SOS?',
    message:
        'Tell the admin why you cannot respond, so they can send someone else to ${name ?? 'them'}.',
    confirmLabel: 'Decline',
  );
  if (reason == null || reason.isEmpty) return false;
  final error = await GobikerSos.instance.decline(id, reason);
  if (context.mounted) {
    AppToast.show(
      context,
      error ?? 'Declined. The admin has been told to send someone else.',
      type: error == null ? ToastType.info : ToastType.error,
    );
  }
  return true;
}
