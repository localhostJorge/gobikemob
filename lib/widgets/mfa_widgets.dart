// Pieces shared by two-step login (MFA): the code field on the Login page and
// in the profile, the "enter a code" dialog, and the list of backup codes.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/patient/app_colors.dart';
import '../screens/patient/ui_kit.dart';
import 'app_text_field.dart';
import 'app_toast.dart';

/// A code from the authenticator app: 6 digits.
final RegExp kMfaCodePattern = RegExp(r'^\d{6}$');

/// A one-time backup code: `xxxx-xxxx` (the dash may be left out).
final RegExp kBackupCodePattern = RegExp(r'^[A-Za-z0-9]{4}-?[A-Za-z0-9]{4}$');

/// The 6-digit code field, or with [backup] the `xxxx-xxxx` backup-code field
/// (up to 9 characters).
class MfaCodeField extends StatelessWidget {
  const MfaCodeField({
    super.key,
    required this.controller,
    this.backup = false,
    this.onSubmitted,
    this.label,
  });

  final TextEditingController controller;
  final bool backup;
  final ValueChanged<String>? onSubmitted;
  final String? label;

  @override
  Widget build(BuildContext context) => AppTextField(
    // A new field when the kind changes, so the keyboard changes with it.
    key: ValueKey(backup ? 'mfa-backup-code' : 'mfa-code'),
    label: label ?? (backup ? 'Backup code' : '6-digit code'),
    hint: backup ? 'xxxx-xxxx' : '123456',
    icon: backup ? Icons.key_outlined : Icons.pin_outlined,
    controller: controller,
    keyboardType: backup ? TextInputType.visiblePassword : TextInputType.number,
    textInputAction: TextInputAction.done,
    autofillHints: backup ? null : const [AutofillHints.oneTimeCode],
    maxLength: backup ? 9 : 6,
    inputFormatters: [
      backup
          ? FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]'))
          : FilteringTextInputFormatter.digitsOnly,
    ],
    validator: (v) {
      final value = (v ?? '').trim();
      if (backup) {
        return kBackupCodePattern.hasMatch(value)
            ? null
            : 'Enter a backup code like abcd-1234';
      }
      return kMfaCodePattern.hasMatch(value)
          ? null
          : 'Enter the 6 digits from your authenticator app';
    },
    onSubmitted: onSubmitted,
  );
}

/// A line of red text under a field: what the server said was wrong.
class MfaError extends StatelessWidget {
  const MfaError(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: T.secondary.copyWith(
          color: context.pal.redText,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Asks for a 6-digit authenticator code, then runs [onSubmit] with it.
/// [onSubmit] returns null when it worked, or the message to show. Returns
/// true once it worked; false when the person cancelled.
Future<bool> askMfaCode(
  BuildContext context, {
  required String title,
  required String message,
  required String actionLabel,
  required Future<String?> Function(String code) onSubmit,
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _MfaCodeDialog(
      title: title,
      message: message,
      actionLabel: actionLabel,
      onSubmit: onSubmit,
      destructive: destructive,
    ),
  );
  return ok == true;
}

class _MfaCodeDialog extends StatefulWidget {
  const _MfaCodeDialog({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onSubmit,
    required this.destructive,
  });

  final String title;
  final String message;
  final String actionLabel;
  final Future<String?> Function(String code) onSubmit;
  final bool destructive;

  @override
  State<_MfaCodeDialog> createState() => _MfaCodeDialogState();
}

class _MfaCodeDialogState extends State<_MfaCodeDialog> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onSubmit(_code.text.trim());
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title, style: T.heading),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.message, style: T.secondary.muted(context)),
            const SizedBox(height: Sp.md),
            MfaCodeField(controller: _code, onSubmitted: (_) => _submit()),
            MfaError(_error),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).pop(false),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: _busy ? null : _submit,
        style: TextButton.styleFrom(
          foregroundColor: widget.destructive ? context.pal.redText : null,
        ),
        child: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(widget.actionLabel),
      ),
    ],
  );
}

/// The one-time backup codes in two columns, with "Copy all".
class BackupCodesList extends StatelessWidget {
  const BackupCodesList({super.key, required this.codes});

  final List<String> codes;

  Future<void> _copyAll(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: codes.join('\n')));
    if (!context.mounted) return;
    AppToast.show(context, 'Backup codes copied.', type: ToastType.success);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppCard(
        child: Wrap(
          spacing: Sp.lg,
          runSpacing: Sp.sm,
          alignment: WrapAlignment.center,
          children: [
            for (final code in codes)
              SizedBox(
                width: 120,
                child: SelectableText(
                  code,
                  textAlign: TextAlign.center,
                  style: T.body.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: Sp.sm),
      SecondaryButton(
        label: 'Copy all',
        icon: Icons.copy_rounded,
        onPressed: () => _copyAll(context),
      ),
    ],
  );
}

/// Shows new backup codes until the person says they saved them.
Future<void> showBackupCodes(BuildContext context, List<String> codes) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Your backup codes', style: T.heading),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Each code works once, if you lose your phone. Keep them '
                'somewhere safe: they are shown only now. Your old codes no '
                'longer work.',
                style: T.secondary.muted(dialogContext),
              ),
              const SizedBox(height: Sp.md),
              BackupCodesList(codes: codes),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('I saved them'),
          ),
        ],
      ),
    );
