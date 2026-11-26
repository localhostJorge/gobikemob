// The "Two-step login" switch on both Profile tabs. On opens the setup page;
// off asks for a code first. While it is on, "New backup codes" replaces the
// saved codes.
import 'package:flutter/material.dart';

import '../core/auth_service.dart';
import '../screens/mfa_setup_screen.dart';
import '../screens/patient/app_colors.dart';
import '../screens/patient/ui_kit.dart';
import 'app_toast.dart';
import 'mfa_widgets.dart';

class TwoStepLoginSettings extends StatefulWidget {
  /// [inCard] for the resident's card rows (a [CardGroup] around it); false
  /// for the GoBiker's plain rows.
  const TwoStepLoginSettings({super.key, this.inCard = true});

  final bool inCard;

  @override
  State<TwoStepLoginSettings> createState() => _TwoStepLoginSettingsState();
}

class _TwoStepLoginSettingsState extends State<TwoStepLoginSettings> {
  bool get _on => AuthService.instance.currentUser?.mfaEnabled ?? false;

  static const _wrongCode = 'That code is wrong. Try again.';

  Future<void> _changed(bool on) async {
    if (on) {
      final turnedOn = await Navigator.of(
        context,
      ).push<bool>(MaterialPageRoute(builder: (_) => const MfaSetupScreen()));
      if (turnedOn == true && mounted) setState(() {});
      return;
    }

    final turnedOff = await askMfaCode(
      context,
      title: 'Turn off two-step login?',
      message:
          'Enter the 6-digit code from your authenticator app. After this, '
          'only your password is needed to log in.',
      actionLabel: 'Turn off',
      destructive: true,
      onSubmit: (code) async {
        final result = await AuthService.instance.mfaDisable(code);
        if (result.ok) return null;
        return result.message.isEmpty ? _wrongCode : result.message;
      },
    );
    if (!turnedOff || !mounted) return;
    setState(() {});
    AppToast.show(context, 'Two-step login is off.', type: ToastType.success);
  }

  Future<void> _newBackupCodes() async {
    var codes = const <String>[];
    final ok = await askMfaCode(
      context,
      title: 'New backup codes',
      message:
          'Enter the 6-digit code from your authenticator app. Your old '
          'backup codes will stop working.',
      actionLabel: 'Get new codes',
      onSubmit: (code) async {
        final result = await AuthService.instance.mfaNewBackupCodes(code);
        if (!result.ok) return result.message ?? _wrongCode;
        codes = result.backupCodes;
        return null;
      },
    );
    if (!ok || !mounted) return;
    await showBackupCodes(context, codes);
  }

  @override
  Widget build(BuildContext context) =>
      widget.inCard ? _cardRows(context) : _plainRows(context);

  Widget _cardRows(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SwitchListTile(
        value: _on,
        onChanged: _changed,
        contentPadding: const EdgeInsets.fromLTRB(Sp.lg, 4, Sp.md, 4),
        secondary: Icon(Icons.shield_outlined, color: context.pal.muted),
        title: const Text('Two-step login', style: T.rowTitle),
        subtitle: Text(
          'A code from an authenticator app after your password',
          style: T.secondary.muted(context),
        ),
      ),
      if (_on) ...[
        Divider(height: 1, indent: 64, color: context.pal.divider),
        NavRow(
          icon: Icons.key_outlined,
          title: 'New backup codes',
          subtitle: 'Replace the codes you saved',
          onTap: _newBackupCodes,
        ),
      ],
    ],
  );

  Widget _plainRows(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface
        .withValues(alpha: 0.6);
    const label = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MergeSemantics(
          child: Row(
            children: [
              Icon(Icons.shield_outlined, size: 22, color: muted),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Two-step login', style: label),
                    Text(
                      'A code from an authenticator app after your password',
                      style: TextStyle(fontSize: 13, color: muted),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _on,
                activeThumbColor: Colors.white,
                onChanged: _changed,
              ),
            ],
          ),
        ),
        if (_on)
          InkWell(
            onTap: _newBackupCodes,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.key_outlined, size: 22, color: muted),
                  const SizedBox(width: 14),
                  const Expanded(child: Text('New backup codes', style: label)),
                  Icon(Icons.chevron_right_rounded, color: muted),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
