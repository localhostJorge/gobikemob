import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/auth_service.dart';
import '../core/theme.dart';
import '../core/tracking_service.dart';
import '../screens/legal_screen.dart';
import 'app_text_field.dart';

/// "Delete account" (Privacy Policy, Section 14). Explains what is deleted and what is kept, asks
/// for the password (or the word DELETE for a Google account without one) and deletes the
/// account on the server. Returns true once the account is gone; the caller then clears what is
/// left on the phone and goes back to Login.
Future<bool> showDeleteAccountSheet(BuildContext context) async {
  final deleted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useRootNavigator: true,
    builder: (_) => const _DeleteAccountSheet(),
  );
  return deleted == true;
}

class _DeleteAccountSheet extends StatefulWidget {
  const _DeleteAccountSheet();

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  static const _supportEmail = 'gobike@pydn.org';

  final _input = TextEditingController();
  bool _busy = false;
  String? _error;

  /// The server refused because the account recorded check-ups (409).
  bool _mustEmail = false;

  AppUser? get _user => AuthService.instance.currentUser;
  bool get _hasPassword => _user?.hasPassword != false;
  bool get _isGoBiker => _user?.isGoBiker == true;
  bool get _onRonda => _isGoBiker && TrackingService.instance.isActive;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final value = _input.text.trim();
    if (value.isEmpty) {
      setState(
        () => _error = _hasPassword
            ? 'Enter your password.'
            : 'Type DELETE to confirm.',
      );
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final res = await AuthService.instance.deleteAccount(
      password: _hasPassword ? _input.text : null,
      confirm: _hasPassword ? null : value,
    );
    if (!mounted) return;

    if (res.ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = res.message;
      _mustEmail = res.status == 409;
    });
  }

  void _openPrivacyPolicy() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LegalScreen(type: LegalType.privacy),
      ),
    );
  }

  Future<void> _emailUs() async {
    await launchUrl(
      Uri(
        scheme: 'mailto',
        path: _supportEmail,
        query: 'subject=Close my RondaGo account',
      ),
    ).catchError((_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.7);
    final body = TextStyle(fontSize: 14, height: 1.5, color: muted);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Delete your account?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                'This permanently deletes your RondaGo account: your profile and photo, '
                'your location, your emergency (SOS) requests with their photos and videos, '
                'your visit requests, ratings and messages. You cannot undo this.',
                style: body,
              ),
              const SizedBox(height: 10),
              Text(
                _isGoBiker
                    ? 'If you recorded check-ups, your account cannot be deleted here, '
                          'because those health records must be kept. Email $_supportEmail '
                          'and we will close it for you.'
                    : 'Check-up records about you are kept by Go Bike for a limited time, '
                          'but are no longer linked to your account.',
                style: body,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _openPrivacyPolicy,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: const Text('Read the Privacy Policy'),
                ),
              ),
              const SizedBox(height: 8),
              if (_onRonda)
                _Notice(
                  icon: Icons.pedal_bike_rounded,
                  text: 'End your ronda before deleting your account.',
                )
              else if (_mustEmail) ...[
                _Notice(icon: Icons.mail_outline_rounded, text: _error ?? ''),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _emailUs,
                  icon: const Icon(Icons.mail_outline_rounded),
                  label: const Text('Email Go Bike'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.blue,
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              ] else ...[
                AppTextField(
                  label: _hasPassword ? 'Password' : 'Type DELETE to confirm',
                  hint: _hasPassword ? 'Your password' : 'DELETE',
                  icon: _hasPassword
                      ? Icons.lock_outline_rounded
                      : Icons.warning_amber_rounded,
                  controller: _input,
                  obscure: _hasPassword,
                  enabled: !_busy,
                  autofillHints: _hasPassword
                      ? const [AutofillHints.password]
                      : null,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _delete(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.errorRed,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _delete,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.errorRed,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Delete my account',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
