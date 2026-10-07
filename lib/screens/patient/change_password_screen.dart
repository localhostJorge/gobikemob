import 'package:flutter/material.dart';

import '../auth_database.dart';
import 'app_colors.dart';
import 'patient_ui.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  // Change this if your create-account screen uses a different minimum.
  static const int _minLength = 6;

  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _saving = false;

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
      return (label: 'Too short', color: AppColors.red);
    }
    if (p.length >= 8 && hasLetter && hasDigit) {
      return (label: 'Strong', color: const Color(0xFF2E9E5B));
    }
    return (
      label: 'Okay - use 8+ characters with letters and numbers',
      color: AppColors.orange,
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;

    setState(() => _saving = true);
    final error = await AuthDatabase.instance.changePassword(
      currentPassword: _current.text,
      newPassword: _new.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('Password changed successfully')),
    );
    Navigator.pop(context);
  }

  Widget _eye(bool shown, VoidCallback onTap) => IconButton(
        icon: Icon(shown ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: AppColors.textMuted),
        onPressed: onTap,
      );

  @override
  Widget build(BuildContext context) {
    final strength = _strength();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: patientAppBar(context, 'Change Password'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Form(
                  key: _form,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enter your current password, then choose a new one '
                        'you don\'t use anywhere else.',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _current,
                        obscureText: !_showCurrent,
                        decoration: inputDecoration(
                          'Current Password',
                          Icons.lock_outline,
                          suffix: _eye(_showCurrent,
                              () => setState(() => _showCurrent = !_showCurrent)),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Enter your current password'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _new,
                        obscureText: !_showNew,
                        decoration: inputDecoration(
                          'New Password',
                          Icons.lock_reset_outlined,
                          suffix: _eye(_showNew,
                              () => setState(() => _showNew = !_showNew)),
                        ),
                        validator: (v) {
                          if (v == null || v.length < _minLength) {
                            return 'Use at least $_minLength characters';
                          }
                          if (v == _current.text) {
                            return 'New password must be different';
                          }
                          return null;
                        },
                      ),
                      if (strength != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(6, 6, 0, 0),
                          child: Text(strength.label,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: strength.color)),
                        ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirm,
                        obscureText: !_showConfirm,
                        decoration: inputDecoration(
                          'Confirm New Password',
                          Icons.check_circle_outline,
                          suffix: _eye(_showConfirm,
                              () => setState(() => _showConfirm = !_showConfirm)),
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
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: primaryButton(
                label: 'UPDATE PASSWORD',
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