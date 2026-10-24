import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'patient_ui.dart';

/// Shown in place of the list when the visits could not be loaded at all.
class VisitsLoadError extends StatelessWidget {
  const VisitsLoadError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 52,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 14),
              const Text(
                "Couldn't load your records",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                    side: const BorderSide(color: AppColors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A slim notice above records that are already on screen when a refresh fails.
class VisitsErrorBanner extends StatelessWidget {
  const VisitsErrorBanner({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        decoration: cardDecoration(12).copyWith(color: AppColors.redSoft),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 18, color: AppColors.red),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Couldn't refresh. Showing your last saved records.\n$message",
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textDark,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.red,
                minimumSize: const Size(48, 48),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Centered spinner for the first load, labelled for screen readers.
class VisitsLoading extends StatelessWidget {
  const VisitsLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: 'Loading your records',
        child: const CircularProgressIndicator(color: AppColors.red),
      ),
    );
  }
}
