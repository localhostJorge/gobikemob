import 'package:flutter/material.dart';

/// The resident app's palette. Brand colors are for fills, big shapes and
/// icons; the `*Text` colors are darker shades that keep small text readable
/// (4.5:1 or better on white).
class AppColors {
  // Brand
  static const red = Color(0xFFE53935);

  /// Fill for buttons with white labels: one shade deeper than [red] so the
  /// label passes 4.5:1 contrast.
  static const redButton = Color(0xFFD32F2F);
  static const redSoft = Color(0xFFFDE8E8);
  static const textDark = Color(0xFF1B1F3B); // navy
  static const background = Color(0xFFF8F5F5);
  static const card = Colors.white;

  // Secondary text and lines
  static const textMuted = Color(0xFF656B79);
  static const line = Color(0xFFECE7E7); // card borders
  static const divider = Color(0xFFF0ECEC); // rules inside a card

  // Accents (fills, icons)
  static const blue = Color(0xFF3B5BDB);
  static const orange = Color(0xFFF2711C);
  static const green = Color(0xFF2E9E5B);

  // The same accents as readable text on white
  static const redText = Color(0xFFC62828);
  static const orangeText = Color(0xFFC2410C);
  static const greenText = Color(0xFF1B7F4B);

  // Skeleton placeholders
  static const skeleton = Color(0xFFE6E0E0);
  static const skeletonShine = Color(0xFFF4F0F0);
}
