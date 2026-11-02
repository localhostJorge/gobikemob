import 'package:flutter/material.dart';

/// The resident app's fixed colors: brand fills, big shapes and icons. They look
/// the same in light and dark mode. Everything that has to change with the theme
/// (pages, cards, text, lines, the readable status shades) lives in [AppPalette].
class AppColors {
  // Brand
  static const red = Color(0xFFE53935);

  /// Fill for buttons with white labels: one shade deeper than [red] so the
  /// label passes 4.5:1 contrast.
  static const redButton = Color(0xFFD32F2F);

  // Accents (fills, icons)
  static const blue = Color(0xFF3B5BDB);
  static const orange = Color(0xFFF2711C);
  static const green = Color(0xFF2E9E5B);

  // The light theme's colors. Read these through `context.pal`, which switches
  // to the dark ones; they stay here for places with no context (const styles).
  static const redSoft = Color(0xFFFDE8E8);
  static const textDark = Color(0xFF1B1F3B); // navy
  static const background = Color(0xFFF8F5F5);
  static const card = Colors.white;
  static const textMuted = Color(0xFF656B79);
  static const line = Color(0xFFECE7E7); // card borders
  static const divider = Color(0xFFF0ECEC); // rules inside a card
  static const redText = Color(0xFFC62828);
  static const orangeText = Color(0xFFC2410C);
  static const greenText = Color(0xFF1B7F4B);
  static const skeleton = Color(0xFFE6E0E0);
  static const skeletonShine = Color(0xFFF4F0F0);
}

/// The colors that change with the theme. The `*Text` colors are shades dark
/// enough (light mode) or light enough (dark mode) to keep small text readable,
/// 4.5:1 or better on [card] and [background].
///
/// Dark mode is the same palette the GoBiker screens use (see `AppTheme`): a
/// near-black page, slightly lighter cards, and a navy outline.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
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
    scrim: Color(0xFF2B2F4A),
  );

  static const dark = AppPalette(
    background: Color(0xFF121318),
    card: Color(0xFF1A1B21),
    line: Color(0xFF2A3752),
    divider: Color(0xFF262A38),
    ink: Color(0xFFE2E2E9),
    muted: Color(0xFFB0B4C3),
    redText: Color(0xFFFF8F89),
    orangeText: Color(0xFFFFB27A),
    greenText: Color(0xFF6FD3A0),
    redSoft: Color(0xFF3A2024),
    skeleton: Color(0xFF26282F),
    skeletonShine: Color(0xFF30323B),
    scrim: Color(0xFF2E3140),
  );

  /// A fixed status color (picked to read on light cards) as text in this theme:
  /// lightened on the dark palette so it stays readable there.
  Color readable(Color c) => background.computeLuminance() < 0.2
      ? Color.lerp(c, Colors.white, 0.55)!
      : c;

  @override
  AppPalette copyWith({
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
  /// The resident palette for the current theme (light if none is set).
  AppPalette get pal =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
