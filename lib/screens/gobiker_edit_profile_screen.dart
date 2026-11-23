import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/auth_service.dart';
import '../widgets/app_text_field.dart';
import '../widgets/app_toast.dart';
import '../widgets/birthday_field.dart';
import '../widgets/location_dropdowns.dart';
import 'patient/app_colors.dart';
import 'patient/ui_kit.dart';

/// The GoBiker's personal information on a page of its own: mobile number, barangay,
/// birthday, and (optionally) a new password. Opened from the Profile tab; returns
/// true once saved.
class GobikerEditProfileScreen extends StatefulWidget {
  const GobikerEditProfileScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<GobikerEditProfileScreen> createState() =>
      _GobikerEditProfileScreenState();
}

class _GobikerEditProfileScreenState extends State<GobikerEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _mobileController = TextEditingController(
    text: widget.user.mobile ?? '',
  );
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late String? _barangay = (widget.user.barangay?.isEmpty ?? true)
      ? null
      : widget.user.barangay;
  // Accounts made before the birthday was asked have none; they can add it here.
  late DateTime? _birthdate = widget.user.birthdate;
  bool _saving = false;

  @override
  void dispose() {
    _mobileController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final result = await AuthService.instance.updateGoBikerProfile(
      mobile: _mobileController.text,
      barangay: _barangay!,
      birthdate: _birthdate,
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
    );

    if (!mounted) return;
    setState(() => _saving = false);
    if (!result.ok) {
      AppToast.show(context, result.message, type: ToastType.error);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: context.pal.background,
        appBar: rondaAppBar(context, 'Edit profile'),
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
                    Sp.xl,
                  ),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SectionHeader('Personal information'),
                          AppTextField(
                            label: 'Mobile number',
                            hint: '09123456789',
                            icon: Icons.phone_outlined,
                            controller: _mobileController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            maxLength: 11,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (value) {
                              if (!RegExp(r'^09\d{9}$')
                                  .hasMatch((value ?? '').trim())) {
                                return 'Use 11 digits starting with 09';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: Sp.lg),
                          LocationDropdowns(
                            initialBarangay: _barangay,
                            onChanged: (value) =>
                                setState(() => _barangay = value),
                            validator: (value) =>
                                value == null ? 'Select your barangay' : null,
                          ),
                          const SizedBox(height: Sp.lg),
                          BirthdayField(
                            value: _birthdate,
                            required: false,
                            onChanged: (date) =>
                                setState(() => _birthdate = date),
                          ),
                          const SizedBox(height: Sp.xl),
                          const SectionHeader('Change password'),
                          Text(
                            'Leave these blank to keep your current password.',
                            style: T.secondary.muted(context),
                          ),
                          const SizedBox(height: Sp.md),
                          AppTextField(
                            label: 'Current password',
                            hint: 'Enter current password',
                            icon: Icons.lock_outline_rounded,
                            controller: _currentPasswordController,
                            obscure: true,
                            autofillHints: const [AutofillHints.password],
                            validator: (value) {
                              if (_newPasswordController.text.isNotEmpty &&
                                  (value == null || value.isEmpty)) {
                                return 'Enter your current password';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: Sp.lg),
                          AppTextField(
                            label: 'New password',
                            hint: 'At least 8 characters',
                            icon: Icons.lock_reset_rounded,
                            controller: _newPasswordController,
                            obscure: true,
                            autofillHints: const [AutofillHints.newPassword],
                            validator: (value) {
                              if (value != null &&
                                  value.isNotEmpty &&
                                  value.length < 8) {
                                return 'Use at least 8 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: Sp.lg),
                          AppTextField(
                            label: 'Confirm new password',
                            hint: 'Re-enter new password',
                            icon: Icons.lock_outline_rounded,
                            controller: _confirmPasswordController,
                            obscure: true,
                            autofillHints: const [AutofillHints.newPassword],
                            validator: (value) {
                              if (_newPasswordController.text.isNotEmpty &&
                                  value != _newPasswordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // The one main action, always in the same spot.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Sp.gutter,
                  Sp.xs,
                  Sp.gutter,
                  Sp.lg,
                ),
                child: PrimaryButton(
                  label: 'Save changes',
                  loading: _saving,
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
