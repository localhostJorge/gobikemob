import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_navigator.dart';
import 'core/emergency_watcher.dart';
import 'core/push_service.dart';
import 'core/theme.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.instance.load();
  await PushService.instance
      .init(); // push notifications (works without them too)
  // When the admin answers an emergency, tell the GoBiker on whatever screen they are on.
  EmergencyWatcher.instance.onAnnounce = showEmergencyAlert;
  runApp(const RondaGoApp());
}

class RondaGoApp extends StatelessWidget {
  const RondaGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'RondaGo',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeController.instance.themeMode,
          // Screens without an app bar (the resident home) would keep dark status-bar
          // icons on a dark page, so the icons follow the theme here, once, for everyone.
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: Theme.of(context).brightness == Brightness.dark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}
