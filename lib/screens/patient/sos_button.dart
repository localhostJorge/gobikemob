import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Hold-to-activate SOS button. The ring around it fills while the user
/// holds; letting go early cancels, so a stray tap never sends an SOS.
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
  static const double _size = 196;
  static const double _ringWidth = 8;

  late final AnimationController _hold;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _hold = AnimationController(vsync: this, duration: widget.holdDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          HapticFeedback.heavyImpact();
          widget.onActivated();
          _hold.reset();
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A gentle pulse draws the eye, unless the phone asks for less motion.
    if (MediaQuery.of(context).disableAnimations) {
      _pulse.stop();
      _pulse.value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
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

  String get _seconds {
    final s = widget.holdDuration.inSeconds;
    return s == 1 ? '1 second' : '$s seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label:
              'SOS. Press and hold for $_seconds to send an emergency '
              'request.',
          excludeSemantics: true,
          child: GestureDetector(
            onTapDown: (_) => _start(),
            onTapUp: (_) => _cancel(),
            onTapCancel: _cancel,
            child: AnimatedBuilder(
              animation: Listenable.merge([_hold, _pulse]),
              builder: (context, _) {
                final holding = _hold.value > 0;
                return SizedBox(
                  width: _size + 24,
                  height: _size + 24,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // One soft halo, breathing slowly.
                      Container(
                        width: _size + 8 + 14 * _pulse.value,
                        height: _size + 8 + 14 * _pulse.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.red.withValues(
                            alpha: 0.08 * (1 - _pulse.value * 0.5),
                          ),
                        ),
                      ),
                      // The track the hold progress runs along.
                      SizedBox(
                        width: _size,
                        height: _size,
                        child: CircularProgressIndicator(
                          value: holding ? _hold.value : 0,
                          strokeWidth: _ringWidth,
                          strokeCap: StrokeCap.round,
                          color: AppColors.red,
                          backgroundColor: AppColors.redSoft,
                        ),
                      ),
                      AnimatedScale(
                        scale: holding ? 0.96 : 1,
                        duration: const Duration(milliseconds: 120),
                        child: Container(
                          width: _size - _ringWidth * 2 - 14,
                          height: _size - _ringWidth * 2 - 14,
                          decoration: const BoxDecoration(
                            color: AppColors.red,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'SOS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 40,
                                  height: 1,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                holding ? 'Keep holding' : 'Press and hold',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Hold for $_seconds to send an SOS',
          style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
