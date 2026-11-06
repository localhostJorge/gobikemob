   import 'package:flutter/material.dart';

import '../core/app_router.dart';
import '../core/auth_service.dart';
import '../core/first_run.dart';
import '../widgets/auth_widgets.dart';
import 'login_screen.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 0.92,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    // Check the saved session while the logo is showing (at least 1.8 seconds).
    final minimumWait = Future.delayed(const Duration(milliseconds: 1800));
    final user = await AuthService.instance.restoreSession();
    // Get Started is for a new user only; everyone else without a session logs in.
    final seen = await FirstRun.seen();
    await minimumWait;

    if (!mounted) return;

    final Widget next = (user != null && canUseMobileApp(user))
        ? screenForUser(user)
        : (seen ? const LoginScreen() : const WelcomeScreen());

    // The logo flies to its place on the next screen (Hero) while the rest fades in.
    final still = MediaQuery.disableAnimationsOf(context);
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: still
            ? Duration.zero
            : const Duration(milliseconds: 700),
        pageBuilder: (context, animation, secondaryAnimation) => next,
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              ),
              child: child,
            ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: authBackground(context),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: const Hero(
                  tag: authLogoHero,
                  child: AuthLogo(height: 120),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              height: 26,
              width: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: kAuthBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
