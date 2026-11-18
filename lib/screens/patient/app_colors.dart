import 'package:flutter/material.dart';

/// The Go Bike colors that look the same in light and dark mode: the brand (from the
/// logo, the app icon and the splash video) and the emergency red. Everything that has
/// to change with the theme (pages, cards, text, lines, readable status shades) lives
/// in [AppPalette].
///
/// Brand rules:
/// - [blue] is the brand: buttons, links, active states. White text on it is 5.6:1.
/// - [navy] is for headings and the big brand surfaces (home header, ronda card).
/// - [orange] is an accent only: dots, badges, highlights, the "Bike". White text on it
///   is 2.6:1, so it never sits behind white text; orange words use `orangeText`.
/// - [red] means emergency (SOS) and danger, nothing else.
class AppColors {
  // Brand
  static const blue = Color(0xFF1667C2);
  static const navy = Color(0xFF0B3D78);
  static const orange = Color(0xFFF58220);

  /// Blue a step darker, for a pressed button.
  static const bluePressed = Color(0xFF0F4F9A);

  // Emergency
  static const red = Color(0xFFE53935);

  /// Fill for SOS and danger buttons with white labels: one shade deeper than [red]
  /// so the label passes 4.5:1 contrast.
  static const redButton = Color(0xFFD32F2F);

  static const green = Color(0xFF2E9E5B);

  // Status fills (icons, tints). As text, read them through `context.pal.tone(...)`.
  static const success = Color(0xFF2E9D67);
  static const danger = Color(0xFFDC4C4C);

  // The light theme's colors. Read these through `context.pal`, which switches
  // to the dark ones; they stay here for places with no context (const styles).
  static const blueSoft = Color(0xFFEAF2FC);
  static const redSoft = Color(0xFFFDE8E8);
  static const textDark = Color(0xFF13233D); // ink
  static const background = Color(0xFFF5F8FC);
  static const card = Colors.white;
  static const textMuted = Color(0xFF5B6577);
  static const line = Color(0xFFE3E9F2); // card borders
  static const divider = Color(0xFFEEF2F7); // rules inside a card
  static const redText = Color(0xFFC62828);
  static const orangeText = Color(0xFFC2410C);
  static const greenText = Color(0xFF1B7F4B);
  static const skeleton = Color(0xFFE4EAF2);
  static const skeletonShine = Color(0xFFF2F5FA);
}

/// The colors that change with the theme. The `*Text` colors are shades dark
/// enough (light mode) or light enough (dark mode) to keep small text readable,
/// 4.5:1 or better on [card] and [background].
///
/// One palette for the whole app, GoBiker and resident screens alike.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brand,
    required this.brandSoft,
    required this.heading,
    required this.accent,
    required this.background,
    required this.card,
    required this.line,
    required this.divider,
    required this.ink,
    required this.muted,
    required this.redText,
    required this.orangeText,
    required this.greenText,
    required this.redSoft,
    required this.skeleton,
    required this.skeletonShine,
    required this.scrim,
  });

  /// Brand blue as text, icons and outlines: links, active tabs, selected states.
  /// Buttons are filled with [AppColors.blue] in both themes (white text on it is
  /// 5.6:1); this is the readable shade for the current page.
  final Color brand;

  /// A pale brand tint: selected pills, icon tiles, info panels.
  final Color brandSoft;

  /// Page and section titles: navy on light pages, near-white on dark ones.
  final Color heading;

  /// The orange accent for dots, badges and highlights (never behind text).
  final Color accent;

  /// The page behind everything.
  final Color background;

  /// Cards, inputs, the bottom bar and dialogs.
  final Color card;

  /// Card borders and outlines.
  final Color line;

  /// Hairlines inside a card.
  final Color divider;

  /// Main text and icons.
  final Color ink;

  /// Secondary text.
  final Color muted;

  final Color redText;
  final Color orangeText;
  final Color greenText;

  /// A pale red panel behind a warning.
  final Color redSoft;

  final Color skeleton;
  final Color skeletonShine;

  /// The dark bar a toast is drawn on, always dark enough for white text.
  final Color scrim;

  static const light = AppPalette(
    brand: AppColors.blue,
    brandSoft: AppColors.blueSoft,
    heading: AppColors.navy,
    accent: AppColors.orange,
    background: AppColors.background,
    card: AppColors.card,
    line: AppColors.line,
    divider: AppColors.divider,
    ink: AppColors.textDark,
    muted: AppColors.textMuted,
    redText: AppColors.redText,
    orangeText: AppColors.orangeText,
    greenText: AppColors.greenText,
    redSoft: AppColors.redSoft,
    skeleton: AppColors.skeleton,
    skeletonShine: AppColors.skeletonShine,
    scrim: Color(0xFF102A4C),
  );

  /// Dark mode: a deep blue-black page, slightly lighter cards, a navy outline, and
  /// the brand blue lifted so it stays readable as text.
  static const dark = AppPalette(
    brand: Color(0xFF6EA8EE),
    brandSoft: Color(0xFF16294A),
    heading: Color(0xFFF2F5FA),
    accent: AppColors.orange,
    background: Color(0xFF0B1220),
    card: Color(0xFF131C2E),
    line: Color(0xFF24324A),
    divider: Color(0xFF1C2840),
    ink: Color(0xFFE6EBF3),
    muted: Color(0xFFA9B4C6),
    redText: Color(0xFFFF8F89),
    orangeText: Color(0xFFFFB27A),
    greenText: Color(0xFF6FD3A0),
    redSoft: Color(0xFF3A2024),
    skeleton: Color(0xFF1C2638),
    skeletonShine: Color(0xFF26324A),
    scrim: Color(0xFF1E2B42),
  );

  /// A fixed status color (picked to read on light cards) as text in this theme:
  /// lightened on the dark palette so it stays readable there.
  Color readable(Color c) => background.computeLuminance() < 0.2
      ? Color.lerp(c, Colors.white, 0.55)!
      : c;

  /// The shade of a brand or status color to use for text and icons in this theme,
  /// readable (4.5:1) on cards and on a pale tint of the same color. The orange and
  /// green fills are too light for text, so they map to their text shades.
  Color tone(Color c) {
    if (c == AppColors.orange) return orangeText;
    if (c == AppColors.success || c == AppColors.green) return greenText;
    if (c == AppColors.danger ||
        c == AppColors.red ||
        c == AppColors.redButton) {
      return redText;
    }
    if (c == AppColors.blue) return brand;
    return readable(c);
  }

  @override
  AppPalette copyWith({
    Color? brand,
    Color? brandSoft,
    Color? heading,
    Color? accent,
    Color? background,
    Color? card,
    Color? line,
    Color? divider,
    Color? ink,
    Color? muted,
    Color? redText,
    Color? orangeText,
    Color? greenText,
    Color? redSoft,
    Color? skeleton,
    Color? skeletonShine,
    Color? scrim,
  }) => AppPalette(
    brand: brand ?? this.brand,
    brandSoft: brandSoft ?? this.brandSoft,
    heading: heading ?? this.heading,
    accent: accent ?? this.accent,
    background: background ?? this.background,
    card: card ?? this.card,
    line: line ?? this.line,
    divider: divider ?? this.divider,
    ink: ink ?? this.ink,
    muted: muted ?? this.muted,
    redText: redText ?? this.redText,
    orangeText: orangeText ?? this.orangeText,
    greenText: greenText ?? this.greenText,
    redSoft: redSoft ?? this.redSoft,
    skeleton: skeleton ?? this.skeleton,
    skeletonShine: skeletonShine ?? this.skeletonShine,
    scrim: scrim ?? this.scrim,
  );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      brand: mix(brand, other.brand),
      brandSoft: mix(brandSoft, other.brandSoft),
      heading: mix(heading, other.heading),
      accent: mix(accent, other.accent),
      background: mix(background, other.background),
      card: mix(card, other.card),
      line: mix(line, other.line),
      divider: mix(divider, other.divider),
      ink: mix(ink, other.ink),
      muted: mix(muted, other.muted),
      redText: mix(redText, other.redText),
      orangeText: mix(orangeText, other.orangeText),
      greenText: mix(greenText, other.greenText),
      redSoft: mix(redSoft, other.redSoft),
      skeleton: mix(skeleton, other.skeleton),
      skeletonShine: mix(skeletonShine, other.skeletonShine),
      scrim: mix(scrim, other.scrim),
    );
  }
}

extension AppPaletteContext on BuildContext {
  /// The app palette for the current theme (light if none is set).
  AppPalette get pal =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
