import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Brand tokens used by the form widgets.
const Color _kBlue = Color(0xFF2E62C8);
const Color _kError = Color(0xFFD93025);

Color _fill(BuildContext c) => Theme.of(c).brightness == Brightness.dark
    ? const Color(0xFF1C2236)
    : const Color(0xFFF5F7FB);

Color _border(BuildContext c) => Theme.of(c).brightness == Brightness.dark
    ? const Color(0xFF2E3650)
    : const Color(0xFFE2E6EE);

Color _hint(BuildContext c) => Theme.of(c).brightness == Brightness.dark
    ? const Color(0xFF7C86A2)
    : const Color(0xFF8A94A6);

OutlineInputBorder _outline(Color color, {double width = 1}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );

InputDecoration _decoration(
  BuildContext context, {
  required String hint,
  required IconData icon,
  required bool focused,
  Widget? suffix,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: _hint(context), fontSize: 15),
    filled: true,
    fillColor: _fill(context),
    counterText: '',
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    prefixIcon: Icon(icon, size: 22, color: focused ? _kBlue : _hint(context)),
    suffixIcon: suffix,
    errorStyle: const TextStyle(color: _kError, fontSize: 12, height: 1.3),
    enabledBorder: _outline(_border(context)),
    disabledBorder: _outline(_border(context)),
    focusedBorder: _outline(_kBlue, width: 1.5),
    errorBorder: _outline(_kError),
    focusedErrorBorder: _outline(_kError, width: 1.5),
  );
}

Widget _labelled(BuildContext context, String label, Widget field) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      const SizedBox(height: 6),
      field,
    ],
  );
}

/// Text field with a label above it. Works in light and dark mode.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    this.controller,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.inputFormatters,
    this.obscure = false,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.enabled = true,
    this.readOnly = false,
  });

  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscure;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool enabled;
  final bool readOnly;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _focused = false;
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    final suffix = widget.obscure
        ? IconButton(
            tooltip: _hidden ? 'Show password' : 'Hide password',
            icon: Icon(
              _hidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              size: 22,
              color: _hint(context),
            ),
            onPressed: () => setState(() => _hidden = !_hidden),
          )
        : null;

    return _labelled(
      context,
      widget.label,
      Focus(
        onFocusChange: (f) => setState(() => _focused = f),
        child: TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          obscureText: _hidden,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          inputFormatters: widget.inputFormatters,
          maxLength: widget.maxLength,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: TextStyle(color: onSurface, fontSize: 15),
          cursorColor: _kBlue,
          decoration: _decoration(
            context,
            hint: widget.hint,
            icon: widget.icon,
            focused: _focused,
            suffix: suffix,
          ),
        ),
      ),
    );
  }
}

/// Dropdown that looks identical to [AppTextField].
class AppDropdownField extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.items,
    required this.value,
    required this.onChanged,
    this.validator,
  });

  final String label;
  final String hint;
  final IconData icon;
  final List<String> items;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return _labelled(
      context,
      label,
      DropdownButtonFormField<String>(
        key: ValueKey(value),
        initialValue: value,
        isExpanded: true,
        validator: validator,
        onChanged: onChanged,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        borderRadius: BorderRadius.circular(14),
        dropdownColor: Theme.of(context).colorScheme.surface,
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: _hint(context)),
        style: TextStyle(color: onSurface, fontSize: 15),
        hint: Text(hint, style: TextStyle(color: _hint(context), fontSize: 15)),
        decoration: _decoration(
          context,
          hint: hint,
          icon: icon,
          focused: false,
        ),
        items: items
            .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
            .toList(),
      ),
    );
  }
}

/// Thin strength bar + word under a password field.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.password});

  final String password;

  int get _score {
    var s = 0;
    if (password.length >= 8) s++;
    if (RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[A-Z]').hasMatch(password)) {
      s++;
    }
    if (RegExp(r'\d').hasMatch(password)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) s++;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final score = _score;
    final (label, color) = score <= 1
        ? ('Weak', const Color(0xFFD93025))
        : score <= 3
        ? ('Fair', const Color(0xFFF29900))
        : ('Strong', const Color(0xFF1E8E3E));
    final filled = score <= 1 ? 1 : (score <= 3 ? 2 : 3);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: i < filled ? color : _border(context),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            if (i < 2) const SizedBox(width: 6),
          ],
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
