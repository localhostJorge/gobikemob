import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/app_router.dart';
import '../core/auth_service.dart';
import '../core/first_run.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/brand.dart';
import 'login_screen.dart';
import 'welcome_screen.dart';

/// Opens the app: plays the Go Bike brand video once while the saved session is checked,
/// then moves on to the right first screen.
///
/// The video is drawn on white (its own background), so it blends into the page on any
/// phone shape. If the video cannot play, or the phone asks for less motion, the plain
/// logo shows for a moment instead.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const String video = 'assets/GoBike-splash.mp4';

  /// Never wait longer than this for the video to end, whatever the player does.
  static const Duration longestWait = Duration(seconds: 7);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

enum _Show { nothingYet, video, logo }

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _logoIn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _logoIn,
    curve: Curves.easeOut,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 0.92,
    end: 1,
  ).animate(CurvedAnimation(parent: _logoIn, curve: Curves.easeOutCubic));

  VideoPlayerController? _video;
  final _videoDone = Completer<void>();
  _Show _show = _Show.nothingYet;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _showLogo();
    } else {
      _playVideo();
    }
    _boot();
  }

  Future<void> _playVideo() async {
    final video = VideoPlayerController.asset(
      SplashScreen.video,
      // Silent and brief: never stop the music someone is already playing.
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _video = video;
    try {
      await video.initialize().timeout(const Duration(seconds: 2));
      if (!mounted) return;
      video.addListener(_watchVideo);
      setState(() => _show = _Show.video);
      await video.play();
    } catch (_) {
      // No video on this phone (a missing codec, a slow start, or a test): show the logo.
      if (mounted) _showLogo();
    }
  }

  void _watchVideo() {
    final value = _video?.value;
    if (value == null) return;
    if (value.isCompleted || value.hasError) _finishVideo();
  }

  void _showLogo() {
    _finishVideo();
    if (_show == _Show.logo) return;
    setState(() => _show = _Show.logo);
    _logoIn.forward();
  }

  void _finishVideo() {
    if (!_videoDone.isCompleted) _videoDone.complete();
  }

  Future<void> _boot() async {
    // Check the saved session while the video (or the logo, for at least 1.8 seconds) shows.
    final minimumWait = Future.delayed(const Duration(milliseconds: 1800));
    final user = await AuthService.instance.restoreSession();
    // Get Started is for a new user only; everyone else without a session logs in.
    final seen = await FirstRun.seen();
    await minimumWait;
    await _videoDone.future.timeout(SplashScreen.longestWait, onTimeout: () {});

    if (!mounted) return;

    final Widget next = (user != null && canUseMobileApp(user))
        ? screenForUser(user)
        : (seen ? const LoginScreen() : const WelcomeScreen());

    // The video ends on white, so the next screen fades in from it. After the plain logo,
    // the logo flies to its place on the next screen (Hero) while the rest fades in.
    final still = MediaQuery.disableAnimationsOf(context);
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: still
            ? Duration.zero
            : const Duration(milliseconds: 600),
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
    _video?.removeListener(_watchVideo);
    _video?.dispose();
    _logoIn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    final Widget body = switch (_show) {
      // The first moment before the video is ready: the same white the video starts on.
      _Show.nothingYet => const SizedBox.expand(),
      _Show.video when video != null => Center(
        child: AspectRatio(
          aspectRatio: video.value.aspectRatio,
          child: ExcludeSemantics(child: VideoPlayer(video)),
        ),
      ),
      _ => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: const Hero(
                  tag: authLogoHero,
                  child: AuthLogo(height: 112),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              height: 26,
              width: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: kGoBikeBlue,
              ),
            ),
          ],
        ),
      ),
    };

    // Always white with dark status-bar icons, as the video is, whatever the app's
    // dark-mode setting.
    return AlwaysLight(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Semantics(
          label: 'Go Bike is starting',
          container: true,
          child: body,
        ),
      ),
    );
  }
}
