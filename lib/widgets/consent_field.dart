import 'package:flutter/material.dart';

import '../core/theme.dart';

/// The GoBiker confirms that the person agreed to the check-up before it is saved. Health
/// readings are sensitive personal information under the Data Privacy Act, so the check-up is
/// taken only with consent (or a parent's or guardian's, for a minor). Part of the form: saving
/// shows the error until it is ticked.
class ConsentField extends FormField<bool> {
  ConsentField({super.key, required ValueChanged<bool> onChanged})
    : super(
        initialValue: false,
        validator: (value) => value == true
            ? null
            : 'Ask for their consent before saving the check-up.',
        builder: (state) {
          final context = state.context;
          final theme = Theme.of(context);
          final hasError = state.hasError;

          void toggle() {
            final next = !(state.value ?? false);
            state.didChange(next);
            onChanged(next);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Material(
                color: theme.colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: hasError ? AppTheme.errorRed : theme.dividerColor,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: toggle,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 6, 14, 6),
                    child: Row(
                      children: [
                        Checkbox(
                          value: state.value ?? false,
                          activeColor: AppTheme.blue,
                          onChanged: (_) => toggle(),
                        ),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Text(
                            'The person agreed to this check-up (or their parent or guardian, if under 18).',
                            style: TextStyle(fontSize: 14, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (hasError)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                  child: Text(
                    state.errorText!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.errorRed,
                    ),
                  ),
                ),
            ],
          );
        },
      );
}
