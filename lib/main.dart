import 'package:flutter/material.dart';

import 'core/app_navigator.dart';
import 'core/emergency_watcher.dart';
import 'core/theme.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.instance.load();
  // When the admin answers an emergency, tell the GoBiker on whatever screen they are on.
  EmergencyWatcher.instance.onAnnounce = showEmergencyAlert;
  runApp(const GoBikeApp());
}

class GoBikeApp extends StatelessWidget {
  const GoBikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'Go Bike',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeController.instance.themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}