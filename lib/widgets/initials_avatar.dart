import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Someone's profile photo, or a round badge with their initials when there
/// is none.
///
/// GoBikers upload a photo when they sign up, so the resident they are sent
/// to can see who is coming. Anyone who signed up before that was required,
/// and every resident, shows initials instead.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(
    this.name, {
    super.key,
    this.imageUrl,
    this.radius = 20,
    this.color = AppTheme.blue,
    this.fontSize,
  });

  final String name;

  /// Their photo on the server, if they have one.
  final String? imageUrl;

  final double radius;
  final Color color;

  /// Defaults to a size that suits [radius].
  final double? fontSize;

  /// First and last initial, e.g. "Juan Dela Cruz" is "JC". "?" with no name.
  static String of(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final initials = Text(
      of(name),
      style: TextStyle(
        fontSize: fontSize ?? radius * 0.66,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );

    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.14),
      // The initials stay underneath, so they show while the photo loads and
      // remain if it cannot be fetched at all.
      child: url == null
          ? initials
          : ClipOval(
              child: Image.network(
                url,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                semanticLabel: name,
                errorBuilder: (_, _, _) => Center(child: initials),
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : Center(child: initials),
              ),
            ),
    );
  }
}
