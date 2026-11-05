import 'package:flutter/material.dart';

import '../core/location_gate.dart';

/// Tells the person why there is no position, once, with a way to fix it.
///
/// Shown only because they asked for their position (they tapped the locate button): it is a
/// snackbar with an "Open settings" action, not a system dialog, so there is nothing for the
/// app to loop on. A second tap replaces the first message instead of stacking another.
void showLocationHelp(
  BuildContext context,
  LocationState state, {
  LocationGate? gate,
}) {
  if (state == LocationState.ready) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(LocationGate.explain(state)),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Open settings',
          onPressed: () =>
              (gate ?? LocationGate.instance).openSettingsFor(state),
        ),
      ),
    );
}
