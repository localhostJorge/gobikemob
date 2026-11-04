import 'package:flutter/material.dart';

import '../core/age.dart';
import 'app_text_field.dart';

/// Opens the date picker for a birthday and returns the date picked, or null if they closed
/// it. Any date up to today can be picked, so that someone under the minimum age is told why
/// they cannot register instead of simply not finding their year.
Future<DateTime?> pickBirthday(
  BuildContext context, {
  DateTime? current,
  DateTime? today,
}) {
  final now = today ?? DateTime.now();
  final end = DateTime(now.year, now.month, now.day);
  return showDatePicker(
    context: context,
    // Opens on the youngest age that may register: the likeliest neighbourhood of the answer.
    initialDate: current ?? latestBirthdate(end),
    firstDate: DateTime(1900),
    lastDate: end,
    helpText: 'Select your birthday',
    initialDatePickerMode: DatePickerMode.year,
  );
}

/// The message under a birthday that is missing or too young, or null when it is fine.
String? birthdayError(
  DateTime? birthdate, {
  required bool required,
  DateTime? today,
}) {
  if (birthdate == null) return required ? 'Select your birthday' : null;
  if (!isOldEnough(birthdate, today ?? DateTime.now())) {
    return 'You must be at least $kMinimumAge years old to register';
  }
  return null;
}

/// A birthday field that looks like the other form fields. Tapping it opens the date picker;
/// the age shows under it once a date is chosen, and a date that is too young is explained
/// at once.
class BirthdayField extends StatefulWidget {
  const BirthdayField({
    super.key,
    required this.value,
    required this.onChanged,
    this.required = true,
    this.label = 'Birthday',
  });

  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  /// Signing up needs one; editing an older account may leave it empty.
  final bool required;
  final String label;

  @override
  State<BirthdayField> createState() => _BirthdayFieldState();
}

class _BirthdayFieldState extends State<BirthdayField> {
  late final TextEditingController _text = TextEditingController(
    text: _show(widget.value),
  );

  static String _show(DateTime? date) =>
      date == null ? '' : birthdateLabel(date);

  @override
  void didUpdateWidget(BirthdayField old) {
    super.didUpdateWidget(old);
    // Changed from outside (not through the picker): keep the shown date in step, after
    // this frame, because the text field must not be told to change while it is building.
    if (old.value != widget.value && _text.text != _show(widget.value)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _text.text = _show(widget.value);
      });
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await pickBirthday(context, current: widget.value);
    if (picked == null || !mounted) return;
    // Setting the text counts as the person editing the field, so the form checks it now
    // and a date that is too young is explained straight away.
    _text.text = _show(picked);
    widget.onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.value;
    final age = date == null ? null : ageFromBirthdate(date, DateTime.now());

    return Semantics(
      button: true,
      label: date == null
          ? '${widget.label}. Not set. Opens a date picker.'
          : '${widget.label}, ${birthdateLabel(date)}. Opens a date picker.',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _pick,
        // The field only shows the date: taps go to the picker, not to a keyboard.
        child: AbsorbPointer(
          child: AppTextField(
            label: widget.label,
            hint: 'Select your birthday',
            icon: Icons.cake_outlined,
            controller: _text,
            readOnly: true,
            helper: (age != null && age >= 0)
                ? 'You are $age years old.'
                : null,
            validator: (_) =>
                birthdayError(widget.value, required: widget.required),
          ),
        ),
      ),
    );
  }
}
