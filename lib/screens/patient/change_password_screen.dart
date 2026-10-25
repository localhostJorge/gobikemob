import 'package:flutter/material.dart';

import '../../core/auth_service.dart';
import 'app_colors.dart';
import 'patient_ui.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  // Same minimum as the server (PUT /api/mobile/password).
  static const int _minLength = 8;

  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _saving = false;

  /// A Google sign-in account sets its first password: no current one.
  final bool _setting = AuthService.instance.currentUser?.hasPassword == false;

  @override
  void initState() {
    super.initState();
    _new.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  ({String label, Color color})? _strength() {
    final p = _new.text;
    if (p.isEmpty) return null;
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(p);
    final hasDigit = RegExp(r'\d').hasMatch(p);
    if (p.length < _minLength) {
      return (label: 'Too short', color: AppColors.redText);
    }
    if (p.length >= 10 && hasLetter && hasDigit) {
      return (label: 'Strong', color: AppColors.greenText);
    }
    return (
      label: 'Okay - use 10+ characters with letters and numbers',
      color: AppColors.orangeText,
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;

    setState(() => _saving = true);
    final result = await AuthService.instance.changePassword(
      currentPassword: _setting ? '' : _current.text,
      newPassword: _new.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    if (!result.ok) {
      messenger.showSnackBar(SnackBar(content: Text(result.message)));
      return;
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('Password changed successfully')),
    );
    Navigator.pop(context);
  }

  Widget _eye(bool shown, VoidCallback onTap) => IconButton(
    icon: Icon(
      shown ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      color: AppColors.textMuted,
    ),
    onPressed: onTap,
  );

  @override
  Widget build(BuildContext context) {
    final strength = _strength();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: patientAppBar(
        context,
        _setting ? 'Set a password' : 'Change password',
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  Sp.gutter,
                  Sp.sm,
                  Sp.gutter,
                  Sp.lg,
                ),
                child: Form(
                  key: _form,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _setting
                            ? 'You signed up with Google. Set a password to '
                                  'also log in with your email.'
                            : 'Enter your current password, then choose a new '
                                  'one you don\'t use anywhere else.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (!_setting) ...[
                        TextFormField(
                          controller: _current,
                          obscureText: !_showCurrent,
                          decoration: inputDecoration(
                            'Current password',
                            Icons.lock_outline,
                            suffix: _eye(
                              _showCurrent,
                              () =>
                                  setState(() => _showCurrent = !_showCurrent),
                            ),
                          ),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Enter your current password'
                              : null,
                        ),
                        const SizedBox(height: Sp.lg),
                      ],
                      TextFormField(
                        controller: _new,
                        obscureText: !_showNew,
                        decoration: inputDecoration(
                          'New password',
                          Icons.lock_reset_outlined,
                          suffix: _eye(
                            _showNew,
                            () => setState(() => _showNew = !_showNew),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.length < _minLength) {
                            return 'Use at least $_minLength characters';
                          }
                          if (!_setting && v == _current.text) {
                            return 'New password must be different';
                          }
                          return null;
                        },
                      ),
                      if (strength != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(6, 6, 0, 0),
                          child: Text(
                            strength.label,
                            style: T.meta.copyWith(
                              fontWeight: FontWeight.w700,
                              color: strength.color,
                            ),
                          ),
                        ),
                      const SizedBox(height: Sp.lg),
                      TextFormField(
                        controller: _confirm,
                        obscureText: !_showConfirm,
                        decoration: inputDecoration(
                          'Confirm new password',
                          Icons.check_circle_outline,
                          suffix: _eye(
                            _showConfirm,
                            () => setState(() => _showConfirm = !_showConfirm),
                          ),
                        ),
                        validator: (v) =>
                            v != _new.text ? 'Passwords do not match' : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Sp.gutter,
                Sp.xs,
                Sp.gutter,
                Sp.lg,
              ),
              child: PrimaryButton(
                label: _setting ? 'Set password' : 'Update password',
                loading: _saving,
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
