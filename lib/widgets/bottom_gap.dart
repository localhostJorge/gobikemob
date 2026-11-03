import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// How much room the phone needs along the bottom edge: the system navigation area, or
/// the strip the home gesture lives in, whichever is taller. Anything you can tap that
/// sits inside it (a tab, a button) fights the phone's own gesture and ends up too low.
double bottomGap(BuildContext context) => math.max(
  MediaQuery.viewPaddingOf(context).bottom,
  MediaQuery.systemGestureInsetsOf(context).bottom,
);

/// What [bottomGap] adds beyond the space a `SafeArea` already leaves. For bars that sit
/// inside a `SafeArea`, which only knows the system navigation area, not the gesture strip.
double extraBottomGap(BuildContext context) => math.max(
  0,
  MediaQuery.systemGestureInsetsOf(context).bottom -
      MediaQuery.viewPaddingOf(context).bottom,
);
