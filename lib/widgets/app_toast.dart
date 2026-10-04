import 'dart:async';

import 'package:flutter/material.dart';

enum ToastType { success, error, info }

class AppToast {
  static OverlayEntry? _activeEntry;

  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 2, milliseconds: 500),
  }) {
    _activeEntry?.remove();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }

    OverlayEntry? entry;
    void dismiss() {
      if (entry == null || _activeEntry != entry) {
        return;
      }
      _activeEntry = null;
      entry.remove();
    }

    entry = OverlayEntry(
      builder: (_) => _ToastWidget(
        message: message,
        type: type,
        onDismiss: dismiss,
      ),
    );

    _activeEntry = entry;
    overlay.insert(entry);

    Timer(duration, () {
      if (_activeEntry == entry) {
        dismiss();
      }
    });
  }
}

class _ToastWidget extends StatefulWidget {
  const _ToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  final String message;
  final ToastType type;
  final VoidCallback onDismiss;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => setState(() => _visible = true));
  }

  void _dismiss() {
    if (!_visible) {
      widget.onDismiss();
      return;
    }
    setState(() => _visible = false);
    Future.delayed(const Duration(milliseconds: 220), () {
      widget.onDismiss();
    });
  }

  IconData _iconForType() {
    switch (widget.type) {
      case ToastType.success:
        return Icons.check_circle_rounded;
      case ToastType.error:
        return Icons.error_rounded;
      case ToastType.info:
        return Icons.info_rounded;
    }
  }

  Color _bgColorForType() {
    switch (widget.type) {
      case ToastType.success:
        return const Color(0xFF2E9D67);
      case ToastType.error:
        return const Color(0xFFDC4C4C);
      case ToastType.info:
        return const Color(0xFF2E62C8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _bgColorForType();

    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: SafeArea(
        child: GestureDetector(
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null && details.primaryVelocity! < -90) {
              _dismiss();
            }
          },
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: AnimatedSlide(
              offset: _visible ? Offset.zero : const Offset(0, -0.35),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(_iconForType(), color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
