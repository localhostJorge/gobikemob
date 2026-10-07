import 'package:flutter/material.dart';

import '../core/app_router.dart';
import '../core/auth_service.dart';
import '../widgets/auth_widgets.dart';
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
    await minimumWait;

    if (!mounted) return;

    final Widget next = (user != null && canUseMobileApp(user))
        ? screenForUser(user)
        : const WelcomeScreen();

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (context, animation, secondaryAnimation) => next,
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
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
                child: const AuthLogo(height: 120),
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
