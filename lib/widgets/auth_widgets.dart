import 'package:flutter/material.dart';

import '../screens/patient/app_colors.dart';
import 'brand.dart';

/// The brand blue on the sign-in pages (see [AppColors.blue]).
const Color kAuthBlue = AppColors.blue;

/// White page in light mode, the theme's dark background in dark mode.
Color authBackground(BuildContext context) {
  final theme = Theme.of(context);
  return theme.brightness == Brightness.dark
      ? theme.scaffoldBackgroundColor
      : Colors.white;
}

/// Checkbox outline that stays visible on any background.
BorderSide authCheckboxSide(BuildContext context) {
  final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
  return WidgetStateBorderSide.resolveWith(
    (states) => BorderSide(
      color: states.contains(WidgetState.selected) ? kAuthBlue : muted,
      width: 1.5,
    ),
  );
}

/// Hero tag shared by the logo on the splash, Get Started and Login screens, so it glides
/// from one to the next instead of jumping.
const authLogoHero = 'auth-logo';

/// The RondaGo icon on the sign-in pages. It carries its own blue background, so it
/// needs no plate in dark mode.
class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key, this.height = 80});

  final double height;

  @override
  Widget build(BuildContext context) => RondaGoIcon(size: height);
}

/// Thin lines with a small "or" in the middle.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    return Row(
      children: [
        Expanded(child: Divider(color: theme.dividerColor)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('or', style: TextStyle(color: muted, fontSize: 13)),
        ),
        Expanded(child: Divider(color: theme.dividerColor)),
      ],
    );
  }
}
