import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../screens/patient/app_colors.dart';

/// The app's one confirmation dialog, for GoBiker and resident screens alike: an
/// optional icon tile, a title, a short explanation, and Cancel / confirm buttons.
///
/// The confirm button is the brand blue, or the emergency red when the action is
/// [destructive] (ending a ronda, deleting, logging out, sending an alert).
class ConfirmModal {
  static Future<bool?> show({
    required BuildContext context,
    IconData? icon,
    Color? color,
    required String title,
    required String description,
    required String confirmText,
    String cancelText = 'Cancel',
    VoidCallback? onConfirm,
    bool? destructive,
  }) {
    // Older call sites mark a dangerous action by its red icon.
    final danger = destructive ?? color == AppTheme.errorRed;
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      // A navy wash on light pages; on dark ones a deeper shade, so the page dims
      // instead of turning blue.
      barrierColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF02060D).withValues(alpha: 0.7)
          : AppColors.navy.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        if (MediaQuery.disableAnimationsOf(context)) return child;
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (context, _, _) => _ConfirmCard(
        icon: icon,
        color: color,
        title: title,
        description: description,
        confirmText: confirmText,
        cancelText: cancelText,
        danger: danger,
        onConfirm: onConfirm,
      ),
    );
  }
}

class _ConfirmCard extends StatelessWidget {
  const _ConfirmCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.confirmText,
    required this.cancelText,
    required this.danger,
    required this.onConfirm,
  });

  final IconData? icon;
  final Color? color;
  final String title;
  final String description;
  final String confirmText;
  final String cancelText;
  final bool danger;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    // The icon in the readable shade of its color for this theme.
    final tint = color == null
        ? (danger ? pal.redText : pal.brand)
        : pal.tone(color!);
    final confirmStyle = danger
        ? FilledButton.styleFrom(
            backgroundColor: AppColors.redButton,
            foregroundColor: Colors.white,
          )
        : null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Material(
          color: pal.card,
          borderRadius: BorderRadius.circular(AppTheme.radiusSheet),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: tint.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusCard,
                        ),
                      ),
                      child: Icon(icon, color: tint, size: 28),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTheme.headingFont,
                      fontSize: 18,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: pal.heading,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: pal.muted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Side by side, or stacked when large text needs the room.
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cancel = OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(cancelText, textAlign: TextAlign.center),
                      );
                      final confirm = FilledButton(
                        style: confirmStyle,
                        onPressed: () {
                          onConfirm?.call();
                          Navigator.of(context).pop(true);
                        },
                        child: Text(confirmText, textAlign: TextAlign.center),
                      );
                      final stacked =
                          MediaQuery.textScalerOf(context).scale(16) > 20 ||
                          constraints.maxWidth < 260;
                      if (stacked) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            confirm,
                            const SizedBox(height: 10),
                            cancel,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: cancel),
                          const SizedBox(width: 12),
                          Expanded(child: confirm),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
