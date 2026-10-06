import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Lets the dashboard move the thumb back to the left (for example after Cancel).
class SlideToStartController {
  _SlideToStartState? _state;
  void reset() => _state?._reset();
}

class SlideToStart extends StatefulWidget {
  const SlideToStart({
    super.key,
    required this.onCompleted,
    this.controller,
    this.label = 'SLIDE TO START RONDA',
  });

  final VoidCallback onCompleted;
  final SlideToStartController? controller;
  final String label;

  @override
  State<SlideToStart> createState() => _SlideToStartState();
}

class _SlideToStartState extends State<SlideToStart>
    with SingleTickerProviderStateMixin {
  static const double _height = 54;
  static const double _thumb = 46;
  static const double _pad = 4;
  static const Color _blue = Color(0xFF2E62C8);

  double _drag = 0;
  bool _dragging = false;
  bool _completed = false;

  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
  }

  @override
  void didUpdateWidget(covariant SlideToStart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller?._state == this) {
        oldWidget.controller?._state = null;
      }
      widget.controller?._state = this;
    }
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) widget.controller?._state = null;
    _shimmer.dispose();
    super.dispose();
  }

  void _reset() {
    if (!mounted) return;
    setState(() {
      _drag = 0;
      _dragging = false;
      _completed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = constraints.maxWidth - _thumb - _pad * 2;
        final progress = maxDrag <= 0 ? 0.0 : (_drag / maxDrag).clamp(0.0, 1.0);

        return Container(
          height: _height,
          decoration: BoxDecoration(
            color: _blue,
            borderRadius: BorderRadius.circular(_height / 2),
          ),
          child: Stack(
            children: [
              // Label with a soft shimmer; fades out as the thumb moves.
              Center(
                child: Opacity(
                  opacity: (1 - progress * 1.4).clamp(0.0, 1.0),
                  child: AnimatedBuilder(
                    animation: _shimmer,
                    builder: (context, child) => ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) => LinearGradient(
                        colors: const [
                          Colors.white70,
                          Colors.white,
                          Colors.white70,
                        ],
                        stops: const [0.3, 0.5, 0.7],
                        transform: _SlidingGradientTransform(
                          _shimmer.value * 2 - 1,
                        ),
                      ).createShader(bounds),
                      child: child,
                    ),
                    child: Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ),

              // Thumb
              AnimatedPositioned(
                duration: _dragging
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: _pad + _drag,
                top: (_height - _thumb) / 2,
                child: GestureDetector(
                  onHorizontalDragStart: (_) {
                    if (_completed) return;
                    setState(() => _dragging = true);
                  },
                  onHorizontalDragUpdate: (details) {
                    if (_completed) return;
                    setState(() {
                      _drag = (_drag + details.delta.dx)
                          .clamp(0.0, maxDrag)
                          .toDouble();
                    });
                  },
                  onHorizontalDragEnd: (_) {
                    if (_completed) return;
                    if (_drag >= maxDrag * 0.8) {
                      setState(() {
                        _drag = maxDrag; // stick to the right
                        _dragging = false;
                        _completed = true;
                      });
                      HapticFeedback.mediumImpact();
                      widget.onCompleted();
                    } else {
                      setState(() {
                        _drag = 0;
                        _dragging = false;
                      });
                    }
                  },
                  child: Container(
                    width: _thumb,
                    height: _thumb,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      _completed
                          ? Icons.check_rounded
                          : Icons.directions_bike_rounded,
                      color: _blue,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform(this.slidePercent);
  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}
