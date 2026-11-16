import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/patient/app_colors.dart';
import 'brand.dart';

/// The navy band at the top of both home screens: the RondaGo icon, a greeting and a
/// line under it, over a faint arc of the logo's loop arrow and its orange dot.
///
/// It runs up under the status bar (whose icons turn light over it) and stays put
/// while the page below scrolls.
class RondaHero extends StatelessWidget {
  const RondaHero({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.subtitleIcon,
    this.trailing,
    this.bottom,
  });

  /// The big line: "Good afternoon, Ana".
  final String title;

  /// A small line above [title], e.g. the greeting when the title is a name.
  final String? eyebrow;

  /// A line under the title: the barangay, the duty status.
  final String? subtitle;
  final IconData? subtitleIcon;

  /// Something at the right of the title row (a status pill).
  final Widget? trailing;

  /// Extra content inside the band, under the title (kept short).
  final Widget? bottom;

  static const _onNavyMuted = Color(0xFFC9D8EE); // 7.6:1 on the navy

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        child: ColoredBox(
          color: AppColors.navy,
          child: Stack(
            children: [
              Positioned(
                right: -22,
                top: top + 2,
                child: const ExcludeSemantics(child: _LoopArc(size: 124)),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, top + 16, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // The icon is its own blue tile; a hairline keeps it off the navy.
                        DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: const RondaGoIcon(size: 44),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (eyebrow != null)
                                Text(
                                  eyebrow!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.3,
                                    color: _onNavyMuted,
                                  ),
                                ),
                              Text(
                                title,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 22,
                                  height: 1.25,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (trailing != null) ...[
                          const SizedBox(width: 8),
                          trailing!,
                        ],
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (subtitleIcon != null) ...[
                            Icon(subtitleIcon, size: 16, color: _onNavyMuted),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              subtitle!,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.3,
                                color: _onNavyMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (bottom != null) ...[
                      const SizedBox(height: 14),
                      bottom!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A quiet echo of the logo: most of a circle (the loop arrow) in faint white, with
/// the orange dot sitting in its gap.
class _LoopArc extends StatelessWidget {
  const _LoopArc({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _LoopArcPainter());
}

class _LoopArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.13;
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final arc = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    // As in the logo: the loop runs from the right side (a little above the middle)
    // down, round the bottom and left, and up to the top, leaving a gap at the
    // upper right. Angles are clockwise from the right; -pi/2 is the top.
    const end = -0.35; // where the loop starts, on the right
    const top = -math.pi / 2;
    canvas.drawArc(rect, end, (top + 2 * math.pi) - end, false, arc);

    // The dot, in the middle of the gap.
    final r = rect.width / 2;
    final c = rect.center;
    const mid = (top + end) / 2;
    final dot = Offset(c.dx + r * math.cos(mid), c.dy + r * math.sin(mid));
    canvas.drawCircle(
      dot,
      stroke * 0.42,
      Paint()..color = AppColors.orange.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
