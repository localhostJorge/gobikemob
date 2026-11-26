import 'package:flutter/material.dart';

import '../widgets/app_text_field.dart';
import '../widgets/app_toast.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/brand.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/mfa_widgets.dart';
import '../core/app_router.dart';
import '../core/auth_service.dart';
import '../core/first_run.dart';
import 'create_account_screen.dart';
import 'forgot_password_screen.dart';
import 'patient/app_colors.dart';

final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mfaFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _mfaController = TextEditingController();

  bool _rememberMe = false;
  bool _isLoading = false;
  // bool _isGoogleLoading = false; // Google sign-in is off (see _handleGoogle).

  /// The password was right and two-step login is on: the code step shows.
  bool _mfaStep = false;

  /// On the code step: a one-time backup code instead of the app's code.
  bool _useBackup = false;

  /// What was wrong with the code, under the code field.
  String? _mfaError;

  /// A green line above the form, as after a password reset.
  String? _notice;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _mfaController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final result = await AuthService.instance.login(
      email: _emailController.text,
      password: _passwordController.text,
      remember: _rememberMe,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.mfaRequired) {
      setState(() {
        _mfaStep = true;
        _useBackup = false;
        _mfaError = null;
        _notice = null;
        _mfaController.clear();
      });
      return;
    }
    await _finishSignIn(result);
  }

  /// The second try, with the code from the authenticator app or a backup code.
  Future<void> _handleMfa() async {
    FocusScope.of(context).unfocus();
    if (!_mfaFormKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _mfaError = null;
    });

    final result = await AuthService.instance.login(
      email: _emailController.text,
      password: _passwordController.text,
      remember: _rememberMe,
      mfaCode: _mfaController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.mfaRequired) {
      setState(() => _mfaError = 'That code is wrong. Try again.');
      return;
    }
    if (!result.ok && !result.cancelled) {
      setState(
        () => _mfaError =
            result.message ?? 'Something went wrong. Please try again.',
      );
      return;
    }
    await _finishSignIn(result);
  }

  void _toggleBackup() => setState(() {
    _useBackup = !_useBackup;
    _mfaError = null;
    _mfaController.clear();
  });

  void _backToPassword() => setState(() {
    _mfaStep = false;
    _mfaError = null;
    _mfaController.clear();
  });

  /// Shared by email login and Google sign-in.
  Future<void> _finishSignIn(AuthResult result) async {
    if (result.cancelled) return; // user closed the Google window

    final user = result.user;
    if (!result.ok || user == null) {
      AppToast.show(
        context,
        result.message ?? 'Something went wrong. Please try again.',
        type: ToastType.error,
      );
      return;
    }

    if (!canUseMobileApp(user)) {
      await AuthService.instance.logout();
      if (!mounted) return;
      AppToast.show(
        context,
        'Admin accounts use the web admin panel.',
        type: ToastType.error,
      );
      return;
    }

    await FirstRun.markSeen(); // an existing user is never a new one
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => screenForUser(user)),
      (route) => false,
    );
  }

  // Google sign-in is switched off for now. To bring it back: uncomment this, the
  // `_isGoogleLoading` field, the Google button and its divider in build(), and put
  // `_isGoogleLoading` back in the LoadingOverlay. AuthService.signInWithGoogle and the
  // server route are untouched.
  //
  // Future<void> _handleGoogle() async {
  //   FocusScope.of(context).unfocus();
  //   setState(() => _isGoogleLoading = true);
  //
  //   final result = await AuthService.instance.signInWithGoogle();
  //
  //   if (!mounted) return;
  //   setState(() => _isGoogleLoading = false);
  //   await _finishSignIn(result);
  // }

  void _goToSignUp() {
    // Pushed, not replaced: Back from Sign up comes back here.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateAccountScreen(fromLogin: true),
      ),
    );
  }

  Future<void> _goToForgotPassword() async {
    FocusScope.of(context).unfocus();
    // Comes back with the email once the password was changed.
    final email = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ForgotPasswordScreen(email: _emailController.text.trim()),
      ),
    );
    if (!mounted || email == null) return;
    setState(() {
      _emailController.text = email;
      _passwordController.clear();
      _notice = 'Password changed. Sign in with your new password.';
    });
  }

  // Always the light page, whatever the app's dark-mode setting.
  @override
  Widget build(BuildContext context) =>
      AlwaysLight(child: Builder(builder: _page));

  Widget _page(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.6);

    // System Back on the code step goes back to the password, not out.
    return PopScope(
      canPop: !_mfaStep,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _mfaStep && !_isLoading) _backToPassword();
      },
      child: LoadingOverlay(
        isLoading:
            _isLoading, // Google off: was `_isLoading || _isGoogleLoading`
        message: _mfaStep ? 'Checking code...' : 'Signing in...', // Google off: was 'Signing in with Google...' for Google
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            resizeToAvoidBottomInset: true,
            backgroundColor: authBackground(context),
            body: SafeArea(
              // The logo and form sit in the middle of the screen, and still scroll
              // when the keyboard is up or the text is large.
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - 48).clamp(
                        0,
                        double.infinity,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // The full Go Bike logo, as the brand video ends: icon, then wordmark.
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Hero(
                                tag: authLogoHero,
                                child: AuthLogo(height: 60),
                              ),
                              SizedBox(width: 14),
                              // On a very narrow phone the wordmark shrinks to fit.
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: GoBikeWordmark(fontSize: 32),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          if (_mfaStep)
                            _mfaPage(context, onSurface, muted)
                          else
                            _passwordPage(context, onSurface, muted),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _passwordPage(
    BuildContext context,
    Color onSurface,
    Color muted,
  ) => AutofillGroup(
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Every Ride Has a Purpose.',
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
            'Stay connected. Stay prepared.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: muted),
          ),
          const SizedBox(height: 32),

          if (_notice != null) ...[
            _Notice(_notice!),
            const SizedBox(height: 16),
          ],

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
            label: 'Password',
            hint: 'Enter your password',
            icon: Icons.lock_outline_rounded,
            controller: _passwordController,
            obscure: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Enter your password' : null,
            onSubmitted: (_) => _handleLogin(),
          ),
          const SizedBox(height: 12),

          // Remember me, and the Forgot password link. A Wrap: on a narrow
          // phone with large text the link drops under the checkbox.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _rememberMe = !_rememberMe),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: _rememberMe,
                          activeColor: kAuthBlue,
                          side: authCheckboxSide(context),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          onChanged: (v) =>
                              setState(() => _rememberMe = v ?? false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Remember me',
                        style: TextStyle(fontSize: 14, color: onSurface),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: _isLoading ? null : _goToForgotPassword,
                style: _linkStyle,
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Primary action
          ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text(
              'Login',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 24),

          // Google sign-in is switched off for now: uncomment this block (the divider and
          // the button) to bring it back, with `_handleGoogle` and `_isGoogleLoading` above.
          // const OrDivider(),
          // const SizedBox(height: 24),
          //
          // // Secondary action
          // OutlinedButton(
          //   onPressed: _isGoogleLoading ? null : _handleGoogle,
          //   style: OutlinedButton.styleFrom(
          //     minimumSize: const Size.fromHeight(52),
          //   ),
          //   child: Row(
          //     mainAxisAlignment: MainAxisAlignment.center,
          //     children: [
          //       Image.asset(
          //         'assets/images/google_logo.png',
          //         height: 22,
          //       ),
          //       const SizedBox(width: 12),
          //       const Text(
          //         'Continue with Google',
          //         style: TextStyle(
          //           fontSize: 15,
          //           fontWeight: FontWeight.w600,
          //         ),
          //       ),
          //     ],
          //   ),
          // ),
          // const SizedBox(height: 24),

          // Tertiary action: plain text link
          // A Wrap, not a Row: on a narrow phone with large text the link drops
          // to the next line instead of running off the screen.
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                "Don't have an account?",
                style: TextStyle(fontSize: 14, color: muted),
              ),
              TextButton(
                onPressed: _goToSignUp,
                style: _linkStyle,
                child: const Text(
                  'Sign Up',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  /// After the password: the code from the authenticator app, or a backup code.
  Widget _mfaPage(BuildContext context, Color onSurface, Color muted) => Form(
    key: _mfaFormKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Two-step login',
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
          _useBackup
              ? 'Enter one of the backup codes you saved. Each code works once.'
              : 'Enter the 6-digit code from your authenticator app.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: muted),
        ),
        const SizedBox(height: 32),
        MfaCodeField(
          controller: _mfaController,
          backup: _useBackup,
          onSubmitted: (_) => _handleMfa(),
        ),
        MfaError(_mfaError),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _isLoading ? null : _toggleBackup,
            style: _linkStyle,
            child: Text(
              _useBackup ? 'Use the code from your app' : 'Use a backup code',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleMfa,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
          child: const Text(
            'Verify',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Lost your phone and backup codes? Ask the admin to turn off MFA.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: muted),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _isLoading ? null : _backToPassword,
            style: _linkStyle,
            child: const Text(
              'Back to login',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    ),
  );

  static final ButtonStyle _linkStyle = TextButton.styleFrom(
    foregroundColor: kAuthBlue,
    minimumSize: const Size(0, 48),
    padding: const EdgeInsets.symmetric(horizontal: 8),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
}

/// A green line with a tick: something worked, as a changed password.
class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final green = context.pal.greenText;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: green, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: green,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
