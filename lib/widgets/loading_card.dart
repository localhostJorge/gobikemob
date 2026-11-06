import 'dart:async';

import 'package:flutter/material.dart';

/// A small card with a spinner and a message, shown over the screen while something finishes.
class LoadingCard extends StatelessWidget {
  const LoadingCard({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// The "Logging out..." card both apps show while the session is closed. It cannot be
/// dismissed; the screen that follows replaces the whole stack, which removes it.
void showLoggingOut(BuildContext context, {bool useRootNavigator = false}) {
  unawaited(
    showDialog<void>(
      context: context,
      useRootNavigator: useRootNavigator,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: LoadingCard(message: 'Logging out...')),
      ),
    ),
  );
}
