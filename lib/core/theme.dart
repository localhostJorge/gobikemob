import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/patient/app_colors.dart';

class AppTheme {
  static const Color navy = Color(0xFF1E1E48);
  static const Color blue = Color(0xFF2E62C8);
  static const Color orange = Color(0xFFF28C28);
  static const Color successGreen = Color(0xFF2E9D67);
  static const Color errorRed = Color(0xFFDC4C4C);
  static const Color infoBlue = Color(0xFF2E62C8);

  /// The toast every SnackBar in the app uses, in both themes: a floating, rounded,
  /// solid dark bar with white text, lifted clear of the bottom navigation. Without
  /// it Flutter draws a full-width bar glued to the nav bar, with text in whatever
  /// colour the text theme gives, which can be dark on dark.
  static SnackBarThemeData _snackBar(AppPalette pal) => SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: pal.scrim,
    elevation: 4,
    insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    contentTextStyle: const TextStyle(
      fontFamily: 'Roboto',
      color: Colors.white,
      fontSize: 14,
      height: 1.35,
      fontWeight: FontWeight.w600,
    ),
    actionTextColor: const Color(0xFFFFB4AE),
    closeIconColor: Colors.white,
  );

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      extensions: const [AppPalette.light],
      colorScheme: ColorScheme.fromSeed(seedColor: blue, brightness: Brightness.light),
      scaffoldBackgroundColor: const Color(0xFFF5F7FB),
      cardColor: Colors.white,
      dividerColor: const Color(0xFFE6EAF2),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: navy,
        elevation: 0,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: _snackBar(AppPalette.light),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: blue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navy,
          side: const BorderSide(color: Color(0xFFD8DDEA)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD8DDEA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD8DDEA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: blue, width: 1.5),
        ),
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: navy, displayColor: navy),
      primaryTextTheme: base.primaryTextTheme.apply(bodyColor: navy, displayColor: navy),
    );
  }

  /// Outline of cards and fields in dark mode (navy, visible on the neutral surfaces).
  static const Color darkLine = Color(0xFF2A3752);

  static ThemeData get darkTheme {
    // Every dark surface comes from this one scheme, so the page, cards,
    // dialogs, sheets and fields can't drift apart.
    final scheme = ColorScheme.fromSeed(seedColor: blue, brightness: Brightness.dark);
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: Brightness.dark,
      extensions: const [AppPalette.dark],
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      cardColor: scheme.surfaceContainerLow,
      dividerColor: darkLine,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: _snackBar(AppPalette.dark),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: blue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: darkLine),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: blue, width: 1.5),
        ),
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
      primaryTextTheme: base.primaryTextTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
    );
  }
}

class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  // Light until the person chooses dark; the phone's own setting is not followed.
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('theme_mode');
    switch (stored) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      default:
        _themeMode = ThemeMode.light;
        break;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
  }
}
