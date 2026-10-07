import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

/// Hold-to-activate SOS button. A progress ring fills while the user holds;
/// releasing early cancels. This prevents accidental emergency requests.
class SosButton extends StatefulWidget {
  final VoidCallback onActivated;
  final Duration holdDuration;

  const SosButton({
    super.key,
    required this.onActivated,
    this.holdDuration = const Duration(seconds: 2),
  });

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> with TickerProviderStateMixin {
  late final AnimationController _hold;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _hold = AnimationController(vsync: this, duration: widget.holdDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          HapticFeedback.heavyImpact();
          widget.onActivated();
          _hold.reset();
        }
      });
  }

  void _start() {
    HapticFeedback.selectionClick();
    _hold.forward();
  }

  void _cancel() {
    if (_hold.status != AnimationStatus.completed) _hold.reverse();
  }

  @override
  void dispose() {
    _hold.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTapDown: (_) => _start(),
          onTapUp: (_) => _cancel(),
          onTapCancel: _cancel,
          child: AnimatedBuilder(
            animation: Listenable.merge([_hold, _pulse]),
            builder: (context, _) {
              final p = _pulse.value;
              return SizedBox(
                width: 210,
                height: 210,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _circle(170 + 16 * p, AppColors.red.withOpacity(0.10)),
                    _circle(144 + 8 * p, AppColors.red.withOpacity(0.18)),
                    Container(
                      width: 118,
                      height: 118,
                      decoration: BoxDecoration(
                        color: AppColors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.red.withOpacity(0.45),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    if (_hold.value > 0)
                      SizedBox(
                        width: 128,
                        height: 128,
                        child: CircularProgressIndicator(
                          value: _hold.value,
                          strokeWidth: 5,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Long press for emergency',
          style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _circle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}