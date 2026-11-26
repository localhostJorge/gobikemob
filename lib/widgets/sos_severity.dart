import 'package:flutter/material.dart';

import '../screens/patient/app_colors.dart';

/// The text color for a severity, green to red, readable on cards in both themes.
/// Null for an SOS that came without one.
Color? severityColor(BuildContext context, String? severity) {
  final pal = context.pal;
  return switch (severity) {
    'low' => pal.greenText,
    'moderate' => pal.amberText,
    'high' => pal.orangeText,
    'critical' => pal.redText,
    _ => null,
  };
}

/// A small pill with the severity in its color, e.g. "Critical".
class SosSeverityChip extends StatelessWidget {
  const SosSeverityChip({
    super.key,
    required this.severity,
    required this.label,
  });

  final String severity;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = severityColor(context, severity) ?? context.pal.muted;
    return Semantics(
      label: 'Severity: $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
