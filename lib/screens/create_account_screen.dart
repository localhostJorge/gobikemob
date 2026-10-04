import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/app_text_field.dart';
import '../widgets/app_toast.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/loading_overlay.dart';
import '../core/auth_service.dart';
import 'legal_screen.dart';
import 'login_screen.dart';

/// Set to false if GoBiker accounts are active right away (no admin approval).
const bool _kGoBikerNeedsApproval = true;

final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final RegExp _mobileRegex = RegExp(r'^09\d{9}$');

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  String selectedRole = 'Resident';
  String? selectedBarangay;
  bool _acceptedTerms = false;
  bool _isLoading = false;

  late final TapGestureRecognizer _termsTap = TapGestureRecognizer()
    ..onTap = _openTerms;
  late final TapGestureRecognizer _privacyTap = TapGestureRecognizer()
    ..onTap = _openPrivacy;

  final List<String> barangays = [
    'Angarian',
    'Asinan',
    'Bañaga',
    'Bacabac',
    'Bolaoen',
    'Buenlag',
    'Cabayaoasan',
    'Cayanga',
    'Gueset',
    'Hacienda',
    'Laguit Centro',
    'Laguit Padilla',
    'Magtaking',
    'Pangascasan',
    'Pantal',
    'Poblacion',
    'Polong',
    'Portic',
    'Salasa',
    'Salomague Norte',
    'Salomague Sur',
    'Samat',
    'San Francisco',
    'Umanday',
  ];

  bool get _isGoBiker => selectedRole == 'GoBiker';

  /// The button enables once everything is filled and Terms is ticked.
  /// Detailed validation (and the red messages) happen when it is pressed.
  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty &&
      _emailController.text.trim().isNotEmpty &&
      _mobileController.text.trim().isNotEmpty &&
      selectedBarangay != null &&
      _passwordController.text.isNotEmpty &&
      _confirmController.text.isNotEmpty &&
      _acceptedTerms;

  @override
  void initState() {
    super.initState();
    for (final c in [
      _nameController,
      _emailController,
      _mobileController,
      _passwordController,
      _confirmController,
    ]) {
      c.addListener(_refresh);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  void _openTerms() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const LegalScreen(type: LegalType.terms),
    ),
  );

  void _openPrivacy() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const LegalScreen(type: LegalType.privacy),
    ),
  );

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Future<void> _handleCreateAccount() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (selectedBarangay == null) {
      AppToast.show(context, 'Please select a Barangay', type: ToastType.error);
      return;
    }
    if (!_acceptedTerms) {
      AppToast.show(
        context,
        'You must accept the Terms of Service',
        type: ToastType.error,
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService.instance.register(
      name: _nameController.text,
      email: _emailController.text,
      mobile: _mobileController.text,
      barangay: selectedBarangay!,
      role: selectedRole,
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.ok) {
      AppToast.show(
        context,
        result.message ?? 'Something went wrong. Please try again.',
        type: ToastType.error,
      );
      return;
    }

    AppToast.show(
      context,
      result.pendingApproval
          ? 'Account created. An admin must approve it before you can log in.'
          : 'Account created successfully! You can log in now.',
      type: result.pendingApproval ? ToastType.info : ToastType.success,
    );
    _goToLogin();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.6);

    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Creating account...',
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: authBackground(context),
          body: SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          tooltip: 'Back to login',
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            color: onSurface,
                          ),
                          onPressed: _goToLogin,
                        ),
                      ),
                      const Center(child: AuthLogo(height: 64)),
                      const SizedBox(height: 16),
                      Text(
                        'Create your account',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Join OneGoBike',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: muted),
                      ),
                      const SizedBox(height: 24),

                      // Role selector
                      Row(
                        children: [
                          Expanded(
                            child: _buildRoleCard(
                              'Resident',
                              Icons.person_rounded,
                              'Request check-ups',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildRoleCard(
                              'GoBiker',
                              Icons.directions_bike_rounded,
                              'Manage visits',
                            ),
                          ),
                        ],
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: (_isGoBiker && _kGoBikerNeedsApproval)
                            ? Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: kAuthBlue.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.info_outline_rounded,
                                        size: 18,
                                        color: kAuthBlue,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'GoBiker accounts need admin approval before you can log in.',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            height: 1.35,
                                            color: onSurface,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                      const SizedBox(height: 24),

                      AppTextField(
                        label: 'Full Name',
                        hint: 'Juan Dela Cruz',
                        icon: Icons.person_outline_rounded,
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter your full name'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      AppTextField(
                        label: 'Email address',
                        hint: 'name@email.com',
                        icon: Icons.mail_outline_rounded,
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return 'Enter your email';
                          if (!_emailRegex.hasMatch(value)) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      AppTextField(
                        label: 'Mobile number',
                        hint: '09123456789',
                        icon: Icons.phone_outlined,
                        controller: _mobileController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        maxLength: 11,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return 'Enter your mobile number';
                          if (!_mobileRegex.hasMatch(value)) {
                            return 'Use 11 digits starting with 09';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      AppDropdownField(
                        label: 'Barangay',
                        hint: 'Select your barangay',
                        icon: Icons.location_on_outlined,
                        items: barangays,
                        value: selectedBarangay,
                        onChanged: (v) => setState(() => selectedBarangay = v),
                        validator: (v) =>
                            v == null ? 'Select your barangay' : null,
                      ),
                      const SizedBox(height: 16),

                      AppTextField(
                        label: 'Create a password',
                        hint: 'At least 8 characters',
                        icon: Icons.lock_outline_rounded,
                        controller: _passwordController,
                        obscure: true,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: (v) => (v == null || v.length < 8)
                            ? 'At least 8 characters'
                            : null,
                      ),
                      PasswordStrengthMeter(password: _passwordController.text),
                      const SizedBox(height: 16),

                      AppTextField(
                        label: 'Confirm password',
                        hint: 'Retype your password',
                        icon: Icons.lock_outline_rounded,
                        controller: _confirmController,
                        obscure: true,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Confirm your password';
                          }
                          if (v != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Terms
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _acceptedTerms,
                              activeColor: kAuthBlue,
                              side: authCheckboxSide(context),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              onChanged: (v) =>
                                  setState(() => _acceptedTerms = v ?? false),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text.rich(
                                TextSpan(
                                  text: 'I agree to the ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: onSurface,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'Terms of Service',
                                      recognizer: _termsTap,
                                      style: const TextStyle(
                                        color: kAuthBlue,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const TextSpan(text: ' and '),
                                    TextSpan(
                                      text: 'Privacy Policy',
                                      recognizer: _privacyTap,
                                      style: const TextStyle(
                                        color: kAuthBlue,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      ElevatedButton(
                        onPressed: (_isLoading || !_canSubmit)
                            ? null
                            : _handleCreateAccount,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account?',
                            style: TextStyle(fontSize: 14, color: muted),
                          ),
                          TextButton(
                            onPressed: _goToLogin,
                            style: TextButton.styleFrom(
                              foregroundColor: kAuthBlue,
                              minimumSize: const Size(0, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Log in',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(String role, IconData icon, String subtitle) {
    final selected = selectedRole == role;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final border = dark ? const Color(0xFF33415F) : const Color(0xFFD8DDEA);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? kAuthBlue.withValues(alpha: 0.08)
              : Colors.transparent,
          border: Border.all(
            color: selected ? kAuthBlue : border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: selected ? kAuthBlue : onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 6),
            Text(
              role,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: selected ? kAuthBlue : onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
