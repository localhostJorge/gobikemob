import 'package:flutter/material.dart';

/// Shows [child], and while [isLoading] covers it with a spinner (and an optional
/// [message]) that nothing can get through: no taps, no scrolling, no keyboard focus,
/// no screen-reader actions, so a button can't be pressed twice while a request is
/// still in flight.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  final bool isLoading;
  final Widget child;
  final String? message;

  @override
  Widget build(BuildContext context) {
    // Always a Stack, so the screen underneath keeps its state (typed text, scroll
    // position) when loading starts and stops instead of being rebuilt from scratch.
    return Stack(
      fit: StackFit.passthrough,
      children: [
        // Out of reach while loading: not focusable, not tappable, not read out.
        ExcludeFocus(
          excluding: isLoading,
          child: ExcludeSemantics(excluding: isLoading, child: child),
        ),
        if (isLoading)
          Positioned.fill(
            child: Semantics(
              container: true,
              liveRegion: true,
              label: message ?? 'Loading',
              // A barrier, not an IgnorePointer: it takes the touches itself, so nothing
              // reaches the screen below, and it cannot be dismissed by tapping.
              child: ModalBarrier(
                dismissible: false,
                color: Colors.black.withValues(alpha: 0.18),
              ),
            ),
          ),
        if (isLoading)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Material(
                  color: Theme.of(context).colorScheme.surface
                      .withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 44,
                          height: 44,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                        if (message != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            message!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
