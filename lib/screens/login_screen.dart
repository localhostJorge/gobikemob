import 'package:flutter/material.dart';

import '../widgets/app_text_field.dart';
import '../widgets/app_toast.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/loading_overlay.dart';
import '../core/app_router.dart';
import '../core/auth_service.dart';
import 'create_account_screen.dart';

final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberMe = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
    await _finishSignIn(result);
  }

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

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => screenForUser(user)),
      (route) => false,
    );
  }

  Future<void> _handleGoogle() async {
    FocusScope.of(context).unfocus();
    setState(() => _isGoogleLoading = true);

    final result = await AuthService.instance.signInWithGoogle();

    if (!mounted) return;
    setState(() => _isGoogleLoading = false);
    await _finishSignIn(result);
  }

  void _goToSignUp() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const CreateAccountScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.6);

    return LoadingOverlay(
      isLoading: _isLoading || _isGoogleLoading,
      message: _isGoogleLoading ? 'Signing in with Google...' : 'Signing in...',
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: authBackground(context),
          body: SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: AuthLogo(height: 88)),
                      const SizedBox(height: 24),
                      Text(
                        'Welcome back',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Log in to continue',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: muted),
                      ),
                      const SizedBox(height: 32),

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
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Enter your password'
                            : null,
                        onSubmitted: (_) => _handleLogin(),
                      ),
                      const SizedBox(height: 12),

                      // Remember me (label now uses theme colors, so it is always visible)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () =>
                              setState(() => _rememberMe = !_rememberMe),
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
                                    onChanged: (v) => setState(
                                      () => _rememberMe = v ?? false,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Remember me',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      const OrDivider(),
                      const SizedBox(height: 24),

                      // Secondary action
                      OutlinedButton(
                        onPressed: _isGoogleLoading ? null : _handleGoogle,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/google_logo.png',
                              height: 22,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Continue with Google',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Tertiary action: plain text link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account?",
                            style: TextStyle(fontSize: 14, color: muted),
                          ),
                          TextButton(
                            onPressed: _goToSignUp,
                            style: TextButton.styleFrom(
                              foregroundColor: kAuthBlue,
                              minimumSize: const Size(0, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Sign Up',
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
}
