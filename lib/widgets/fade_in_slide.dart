import 'dart:async';

import 'package:flutter/material.dart';

class FadeInSlide extends StatefulWidget {
  const FadeInSlide({
    super.key,
    required this.child,
    this.delay = const Duration(milliseconds: 0),
    this.offset = const Offset(0, 16),
    this.curve = Curves.easeOutCubic,
    this.duration = const Duration(milliseconds: 450),
  });

  final Widget child;
  final Duration delay;
  final Offset offset;
  final Curve curve;
  final Duration duration;

  @override
  State<FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<FadeInSlide> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Timer(widget.delay, () {
      if (mounted) {
        setState(() => _visible = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: widget.duration,
      curve: widget.curve,
      child: Transform.translate(
        offset: _visible ? Offset.zero : widget.offset,
        child: widget.child,
      ),
    );
  }
}
