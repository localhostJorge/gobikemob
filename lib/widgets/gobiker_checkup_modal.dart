import 'package:flutter/material.dart';

import '../core/live_map.dart';

/// Showed when a resident taps a GoBiker marker on the live map.
/// Provides a "Request Checkup" button that navigates to the AppointmentScreen
/// with the selected GoBiker pre-filled.
class GobikerCheckupModal extends StatelessWidget {
  const GobikerCheckupModal({
    required this.gobiker,
    required this.onRequestCheckup,
    super.key,
  });

  final MapPerson gobiker;
  final VoidCallback onRequestCheckup;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _photoDisplay(
                      gobiker.photoUrl,
                      size: 56,
                      context: context,
                      name: gobiker.name,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            gobiker.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Status: Active',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.medical_services_rounded),
                    label: const Text('Request Checkup'),
                    onPressed: onRequestCheckup,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Displays a GoBiker's photo with fallback to initials.
Widget _photoDisplay(
  String? photoUrl, {
  required double size,
  required BuildContext context,
  required String name,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  if (photoUrl == null) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.secondary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isEmpty ? '?' : name[0].toUpperCase(),
          style: TextStyle(
            color: colorScheme.secondary,
            fontSize: size * 0.35,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  return ClipRRect(
    borderRadius: BorderRadius.circular(size / 2),
    child: Image.network(
      photoUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          _photoErrorPlaceholder(size, context, name),
    ),
  );
}

Widget _photoErrorPlaceholder(double size, BuildContext context, String name) {
  final colorScheme = Theme.of(context).colorScheme;
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: colorScheme.secondary.withValues(alpha: 0.1),
      shape: BoxShape.circle,
    ),
    child: Center(
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: TextStyle(
          color: colorScheme.secondary,
          fontSize: size * 0.35,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}
