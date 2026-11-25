import 'package:flutter/material.dart';

import '../screens/patient/app_colors.dart';

/// Asks the GoBiker why they are turning an assigned SOS down. The reason is
/// required — the admin needs it to pick the right replacement — so the
/// decline button stays disabled until they write something. Returns the
/// reason, or null when they changed their mind.
Future<String?> showDeclineReasonDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String keepLabel = 'Go back',
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DeclineReasonDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      keepLabel: keepLabel,
    ),
  );
}

class _DeclineReasonDialog extends StatefulWidget {
  const _DeclineReasonDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.keepLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String keepLabel;

  @override
  State<_DeclineReasonDialog> createState() => _DeclineReasonDialogState();
}

class _DeclineReasonDialogState extends State<_DeclineReasonDialog> {
  final _reason = TextEditingController();
  bool _touched = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _changed(String _) {
    // Errors appear once they type, not on the untouched field they opened.
    if (!_touched && _reason.text.trim().isNotEmpty) _touched = true;
    setState(() {});
  }

  String? get _error {
    if (!_touched) return null;
    if (_reason.text.trim().isEmpty) {
      return 'Please tell the admin why you cannot respond.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    // The barrier does not dismiss; the buttons below are the only way out.
    canPop: true,
    child: AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            autofocus: true,
            maxLength: 500,
            maxLines: 3,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            onChanged: _changed,
            decoration: InputDecoration(
              labelText: 'Reason (required)',
              hintText: 'e.g. My bike has a flat tire',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(widget.keepLabel),
        ),
        FilledButton(
          // A decline without a reason never leaves the phone.
          onPressed: _reason.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, _reason.text.trim()),
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            backgroundColor: AppColors.redButton,
            disabledBackgroundColor: AppColors.redButton.withValues(alpha: 0.4),
          ),
          child: Text(widget.confirmLabel),
        ),
      ],
    ),
  );
}
