// "Forgot password": the server emails a 6-digit code, and the code sets a new
// password. It does not log in: every phone is signed out, and this page goes
// back to Login with the email filled in.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/auth_service.dart';
import '../widgets/app_text_field.dart';
import '../widgets/app_toast.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/mfa_widgets.dart';

final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// A code can be sent again after this long.
const Duration kResendWait = Duration(seconds: 60);

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.email = ''});

  /// What was typed on the Login page, if anything.
  final String email;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailForm = GlobalKey<FormState>();
  final _resetForm = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;
  String _busyMessage = '';

  /// The code was sent: the second step shows.
  bool _sent = false;

  /// The generic "if that email has an account" line.
  String? _sentMessage;

  String? _codeError;
  String? _passwordError;

  Timer? _timer;
  int _wait = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _startWait() {
    _timer?.cancel();
    setState(() => _wait = kResendWait.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _wait--);
      if (_wait <= 0) timer.cancel();
    });
  }

  Future<bool> _send() async {
    setState(() {
      _busy = true;
      _busyMessage = 'Sending code...';
    });
    final result = await AuthService.instance.forgotPassword(_email.text);
    if (!mounted) return false;
    setState(() => _busy = false);
    if (!result.ok) {
      AppToast.show(context, result.message, type: ToastType.error);
      return false;
    }
    setState(() => _sentMessage = result.message);
    _startWait();
    return true;
  }

  Future<void> _sendFirst() async {
    FocusScope.of(context).unfocus();
    if (!_emailForm.currentState!.validate()) return;
    if (await _send() && mounted) setState(() => _sent = true);
  }

  Future<void> _resend() async {
    if (_wait > 0 || _busy) return;
    setState(() {
      _codeError = null;
      _code.clear();
    });
    if (await _send() && mounted) {
      AppToast.show(context, 'We sent a new code.', type: ToastType.success);
    }
  }

  Future<void> _reset() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _codeError = null;
      _passwordError = null;
    });
    if (!_resetForm.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _busyMessage = 'Changing password...';
    });
    final result = await AuthService.instance.resetPassword(
      email: _email.text,
      code: _code.text,
      password: _password.text,
      passwordConfirmation: _confirm.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.ok) {
      Navigator.of(context).pop(_email.text.trim());
      return;
    }
    switch (result.field) {
      case 'code':
        setState(() => _codeError = result.message);
      case 'password':
        setState(() => _passwordError = result.message);
      default:
        AppToast.show(
          context,
          result.message ?? 'Something went wrong. Please try again.',
          type: ToastType.error,
        );
    }
  }

  /// Back on the code step goes to the email step; on the email step, to Login.
  void _back() {
    if (_sent && !_busy) {
      setState(() {
        _sent = false;
        _codeError = null;
        _passwordError = null;
      });
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) =>
      AlwaysLight(child: Builder(builder: _page));

  Widget _page(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.6);

    return PopScope(
      canPop: !_sent,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: LoadingOverlay(
        isLoading: _busy,
        message: _busyMessage,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            resizeToAvoidBottomInset: true,
            backgroundColor: authBackground(context),
            body: SafeArea(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        tooltip: _sent ? 'Back' : 'Back to login',
                        icon: Icon(Icons.arrow_back_rounded, color: onSurface),
                        onPressed: _back,
                      ),
                    ),
                    const Center(child: AuthLogo(height: 64)),
                    const SizedBox(height: 16),
                    Text(
                      _sent ? 'Enter the code' : 'Forgot password',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 22,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _sent
                          ? (_sentMessage ??
                                'If that email has an account, we sent a code.')
                          : "Enter your account's email. We'll send a "
                                '6-digit code to set a new password.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: muted),
                    ),
                    const SizedBox(height: 28),
                    if (_sent) _resetStep(context, muted) else _emailStep(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emailStep() => Form(
    key: _emailForm,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: 'Email address',
          hint: 'name@email.com',
          icon: Icons.mail_outline_rounded,
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          validator: (v) {
            final value = (v ?? '').trim();
            if (value.isEmpty) return 'Enter your email';
            if (!_emailRegex.hasMatch(value)) return 'Enter a valid email';
            return null;
          },
          onSubmitted: (_) => _sendFirst(),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _busy ? null : _sendFirst,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
          child: const Text(
            'Send code',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  Widget _resetStep(BuildContext context, Color muted) => AutofillGroup(
    child: Form(
      key: _resetForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: 'Code from the email',
            hint: '123456',
            icon: Icons.pin_outlined,
            controller: _code,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.oneTimeCode],
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) => kMfaCodePattern.hasMatch((v ?? '').trim())
                ? null
                : 'Enter the 6 digits from the email',
          ),
          MfaError(_codeError),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _wait > 0 || _busy ? null : _resend,
              style: TextButton.styleFrom(
                foregroundColor: kAuthBlue,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _wait > 0 ? 'Send a new code in ${_wait}s' : 'Send a new code',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          AppTextField(
            label: 'New password',
            hint: 'At least 8 characters',
            icon: Icons.lock_outline_rounded,
            controller: _password,
            obscure: true,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            onChanged: (_) => setState(() {}),
            validator: (v) =>
                (v == null || v.length < 8) ? 'At least 8 characters' : null,
          ),
          PasswordStrengthMeter(password: _password.text),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Confirm new password',
            hint: 'Retype your new password',
            icon: Icons.lock_outline_rounded,
            controller: _confirm,
            obscure: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            validator: (v) {
              if (v == null || v.isEmpty) return 'Confirm your password';
              if (v != _password.text) return 'Passwords do not match';
              return null;
            },
            onSubmitted: (_) => _reset(),
          ),
          MfaError(_passwordError),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _busy ? null : _reset,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text(
              'Change password',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Changing your password signs you out on every phone.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: muted),
          ),
        ],
      ),
    ),
  );
}
