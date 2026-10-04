import 'package:flutter/material.dart';

const Color kAuthBlue = Color(0xFF2E62C8);

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

/// Logo. In dark mode it sits on a white rounded plate so it stays readable.
class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key, this.height = 80});

  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final logo = Image.asset('assets/images/logo.png', height: height);
    if (!dark) return logo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: logo,
    );
  }
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
