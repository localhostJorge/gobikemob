import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Asks the GoBiker for an optional reason before they turn a visit down, and returns it
/// ('' for none) or null when they change their mind. The resident is shown the reason.
Future<String?> showVisitNoteDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String keepLabel = 'Keep it',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _VisitNoteDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      keepLabel: keepLabel,
    ),
  );
}

class _VisitNoteDialog extends StatefulWidget {
  const _VisitNoteDialog({
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
  State<_VisitNoteDialog> createState() => _VisitNoteDialogState();
}

class _VisitNoteDialogState extends State<_VisitNoteDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.message),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          maxLength: 300,
          maxLines: 3,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'e.g. I am out of town that day',
            border: OutlineInputBorder(),
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
        onPressed: () => Navigator.pop(context, _note.text.trim()),
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: AppTheme.errorRed,
        ),
        child: Text(widget.confirmLabel),
      ),
    ],
  );
}
