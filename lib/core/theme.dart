import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/patient/app_colors.dart';

/// The Go Bike theme: one design system for the GoBiker and resident screens, built
/// on the brand colors of the logo, app icon and splash video (see [AppColors]).
///
/// Light and dark are built by the same code from [AppPalette.light] and
/// [AppPalette.dark], so the two can't drift apart.
class AppTheme {
  // Brand (the same in both themes). Kept under these names for older call sites.
  static const Color navy = AppColors.navy;
  static const Color blue = AppColors.blue;
  static const Color orange = AppColors.orange;
  static const Color infoBlue = AppColors.blue;

  // Status
  static const Color successGreen = AppColors.success;
  static const Color errorRed = AppColors.danger;

  /// Outline of cards and fields in dark mode.
  static const Color darkLine = Color(0xFF24324A);

  /// Headings, page titles and big numbers. Body text stays in [bodyFont].
  static const String headingFont = 'Poppins';
  static const String bodyFont = 'Roboto';

  /// Corner radius of buttons and inputs, cards, and dialogs/sheets.
  static const double radiusControl = 12;
  static const double radiusCard = 16;
  static const double radiusSheet = 24;

  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final pal = dark ? AppPalette.dark : AppPalette.light;

    // Field and control outlines: a step stronger than card hairlines.
    final fieldLine = dark ? const Color(0xFF2E3E5A) : const Color(0xFFD3DCE8);
    final outline = dark ? const Color(0xFF6B7A93) : const Color(0xFF8D97A8);

    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.blue,
          brightness: brightness,
        ).copyWith(
          // As a fill (buttons) the brand blue stays the same in both themes; as text
          // and icons on a dark page it is lifted (pal.brand) so it stays readable.
          primary: pal.brand,
          onPrimary: dark ? pal.background : Colors.white,
          primaryContainer: pal.brandSoft,
          onPrimaryContainer: dark ? const Color(0xFFD6E6FB) : AppColors.navy,
          secondary: AppColors.orange,
          onSecondary: AppColors.navy,
          tertiary: AppColors.navy,
          onTertiary: Colors.white,
          error: dark ? pal.redText : AppColors.redButton,
          onError: dark ? pal.background : Colors.white,
          surface: pal.background,
          onSurface: pal.ink,
          onSurfaceVariant: pal.muted,
          surfaceContainerLowest: pal.card,
          surfaceContainerLow: pal.card,
          surfaceContainer: pal.card,
          surfaceContainerHigh: pal.card,
          surfaceContainerHighest: pal.divider,
          outline: outline,
          outlineVariant: pal.line,
          surfaceTint: Colors.transparent,
          shadow: AppColors.navy,
          scrim: Colors.black,
        );

    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusControl),
    );
    const buttonText = TextStyle(
      fontFamily: bodyFont,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    );
    const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);
    const buttonMinSize = Size(64, 48);

    // The main call to action: brand blue with white text in both themes.
    final filledStyle = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return pal.line;
        }
        if (states.contains(WidgetState.pressed)) {
          return AppColors.bluePressed;
        }
        return AppColors.blue;
      }),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.disabled) ? pal.muted : Colors.white,
      ),
      overlayColor: WidgetStatePropertyAll(
        Colors.white.withValues(alpha: 0.08),
      ),
      elevation: const WidgetStatePropertyAll(0),
      shape: WidgetStatePropertyAll(controlShape),
      padding: const WidgetStatePropertyAll(buttonPadding),
      minimumSize: const WidgetStatePropertyAll(buttonMinSize),
      textStyle: const WidgetStatePropertyAll(buttonText),
    );

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusControl),
      borderSide: BorderSide(color: fieldLine),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: bodyFont,
      extensions: [pal],
      colorScheme: scheme,
      scaffoldBackgroundColor: pal.background,
      canvasColor: pal.background,
      cardColor: pal.card,
      dividerColor: pal.line,
      dividerTheme: DividerThemeData(color: pal.line, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: pal.ink),
      appBarTheme: AppBarTheme(
        backgroundColor: pal.background,
        foregroundColor: pal.heading,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: headingFont,
          fontSize: 18,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: pal.heading,
        ),
      ),
      cardTheme: CardThemeData(
        color: pal.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: pal.line),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: pal.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSheet),
        ),
        titleTextStyle: TextStyle(
          fontFamily: headingFont,
          fontSize: 18,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: pal.heading,
        ),
        contentTextStyle: TextStyle(
          fontFamily: bodyFont,
          fontSize: 15,
          height: 1.45,
          color: pal.ink,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: pal.card,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: pal.line,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusSheet),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        // A floating, rounded, solid dark bar with white text, lifted clear of the
        // bottom navigation, in both themes.
        behavior: SnackBarBehavior.floating,
        backgroundColor: pal.scrim,
        elevation: 4,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusControl),
        ),
        contentTextStyle: const TextStyle(
          fontFamily: bodyFont,
          color: Colors.white,
          fontSize: 14,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
        // The light orange reads on the dark bar (9:1).
        actionTextColor: AppPalette.dark.orangeText,
        closeIconColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: filledStyle),
      filledButtonTheme: FilledButtonThemeData(style: filledStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: pal.brand,
          side: BorderSide(color: fieldLine),
          shape: controlShape,
          padding: buttonPadding,
          minimumSize: buttonMinSize,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: pal.brand,
          shape: controlShape,
          minimumSize: const Size(48, 44),
          textStyle: buttonText.copyWith(fontSize: 15),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
        extendedTextStyle: buttonText,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: pal.card,
        hintStyle: TextStyle(color: pal.muted),
        labelStyle: TextStyle(color: pal.muted),
        floatingLabelStyle: TextStyle(color: pal.brand),
        prefixIconColor: pal.muted,
        suffixIconColor: pal.muted,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: pal.brand, width: 1.5),
        ),
        errorBorder: border.copyWith(
          borderSide: BorderSide(color: pal.redText),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: BorderSide(color: pal.redText, width: 1.5),
        ),
        errorStyle: TextStyle(color: pal.redText),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: pal.brand,
        selectionColor: pal.brand.withValues(alpha: 0.3),
        selectionHandleColor: pal.brand,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: pal.brand,
        linearTrackColor: pal.brandSoft,
        circularTrackColor: Colors.transparent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? Colors.white : outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.blue
              : pal.divider,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? AppColors.blue : outline,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.blue
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: BorderSide(color: outline, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? pal.brand : outline,
        ),
      ),
      chipTheme: ChipThemeData(
        // Selected: solid brand blue with white text (5.6:1), in both themes.
        backgroundColor: pal.card,
        selectedColor: AppColors.blue,
        disabledColor: pal.divider,
        side: BorderSide(color: pal.line),
        checkmarkColor: Colors.white,
        shape: const StadiumBorder(),
        labelStyle: TextStyle(
          fontFamily: bodyFont,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: pal.ink,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: bodyFont,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: pal.brand,
        unselectedLabelColor: pal.muted,
        indicatorColor: pal.brand,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: pal.line,
        labelStyle: const TextStyle(
          fontFamily: bodyFont,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: bodyFont,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: AppColors.redButton,
        textColor: Colors.white,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: pal.card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: pal.brandSoft,
        elevation: 0,
        height: 68,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? pal.brand
                : pal.muted,
            size: 24,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: bodyFont,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? pal.brand
                : pal.muted,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: pal.card,
        selectedItemColor: pal.brand,
        unselectedItemColor: pal.muted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(
          fontFamily: bodyFont,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: bodyFont,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: pal.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          side: BorderSide(color: pal.line),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: pal.muted,
        textColor: pal.ink,
      ),
    );

    // Big type in Poppins (as the RondaGo wordmark), everything else in Roboto.
    TextStyle? heading(TextStyle? s, FontWeight w) =>
        s?.copyWith(fontFamily: headingFont, fontWeight: w);
    final text = base.textTheme.apply(
      bodyColor: pal.ink,
      displayColor: pal.heading,
    );
    final textTheme = text.copyWith(
      displayLarge: heading(text.displayLarge, FontWeight.w700),
      displayMedium: heading(text.displayMedium, FontWeight.w700),
      displaySmall: heading(text.displaySmall, FontWeight.w700),
      headlineLarge: heading(text.headlineLarge, FontWeight.w700),
      headlineMedium: heading(text.headlineMedium, FontWeight.w700),
      headlineSmall: heading(text.headlineSmall, FontWeight.w600),
      titleLarge: heading(
        text.titleLarge,
        FontWeight.w600,
      )?.copyWith(color: pal.heading),
    );

    return base.copyWith(textTheme: textTheme, primaryTextTheme: textTheme);
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
