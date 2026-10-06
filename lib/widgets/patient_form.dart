import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_text_field.dart';

/// Holds the controllers for every patient field and converts to/from the
/// map format used by globalPatients (same keys as before).
class PatientFormControllers {
  PatientFormControllers([Map<String, dynamic>? patient]) {
    if (patient != null) fill(patient);
  }

  final name = TextEditingController();
  final address = TextEditingController();
  final contact = TextEditingController();
  final age = TextEditingController();
  final sys = TextEditingController();
  final dia = TextEditingController();
  final pulse = TextEditingController();
  final resp = TextEditingController();
  final temp = TextEditingController();
  final height = TextEditingController();
  final weight = TextEditingController();

  List<TextEditingController> get _all => [
    name,
    address,
    contact,
    age,
    sys,
    dia,
    pulse,
    resp,
    temp,
    height,
    weight,
  ];

  void fill(Map<String, dynamic> p) {
    name.text = p['name']?.toString() ?? '';
    address.text = p['address']?.toString() ?? '';
    contact.text = p['contact']?.toString() ?? '';
    age.text = p['age']?.toString() ?? '';
    sys.text = p['sys']?.toString() ?? '';
    dia.text = p['dia']?.toString() ?? '';
    pulse.text = p['pulse']?.toString() ?? '';
    resp.text = p['resp']?.toString() ?? '';
    temp.text = p['temp']?.toString() ?? '';
    height.text = p['height']?.toString() ?? '';
    weight.text = p['weight']?.toString() ?? '';
  }

  Map<String, dynamic> toMap() => {
    'name': name.text.trim(),
    'address': address.text.trim(),
    'contact': contact.text.trim(),
    'age': age.text.trim(),
    'sys': sys.text.trim(),
    'dia': dia.text.trim(),
    'pulse': pulse.text.trim(),
    'resp': resp.text.trim(),
    'temp': temp.text.trim(),
    'height': height.text.trim(),
    'weight': weight.text.trim(),
  };

  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
  }
}

String? _required(String? v) =>
    (v == null || v.trim().isEmpty) ? 'Required' : null;

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

String? Function(String?) _range(double min, double max) {
  return (v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return 'Required';
    final n = double.tryParse(text);
    if (n == null) return 'Enter a number';
    if (n < min || n > max) return 'Use ${_fmt(min)}-${_fmt(max)}';
    return null;
  };
}

final List<TextInputFormatter> _digits = [
  FilteringTextInputFormatter.digitsOnly,
];
final List<TextInputFormatter> _decimal = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
];

/// The full patient form (personal details + vital signs).
class PatientForm extends StatelessWidget {
  const PatientForm({
    super.key,
    required this.controllers,
    this.readOnly = false,
  });

  final PatientFormControllers controllers;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final c = controllers;
    final muted = Theme.of(context).colorScheme.onSurface
        .withValues(alpha: 0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader('PERSONAL DETAILS', muted),
        AppTextField(
          label: 'Full name',
          hint: 'Juan Dela Cruz',
          icon: Icons.person_outline_rounded,
          controller: c.name,
          readOnly: readOnly,
          textInputAction: TextInputAction.next,
          validator: _required,
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Address',
          hint: 'House no., street, purok',
          icon: Icons.home_outlined,
          controller: c.address,
          readOnly: readOnly,
          textInputAction: TextInputAction.next,
          validator: _required,
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: AppTextField(
                label: 'Contact number',
                hint: '09123456789',
                icon: Icons.phone_outlined,
                controller: c.contact,
                readOnly: readOnly,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                inputFormatters: _digits,
                maxLength: 11,
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'Required';
                  if (t.length < 7) return 'Too short';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: AppTextField(
                label: 'Age',
                hint: '45',
                icon: Icons.cake_outlined,
                controller: c.age,
                readOnly: readOnly,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: _digits,
                maxLength: 3,
                validator: _range(0, 120),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _SectionHeader('VITAL SIGNS', muted),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                label: 'Systolic (mmHg)',
                hint: '120',
                icon: Icons.monitor_heart_outlined,
                controller: c.sys,
                readOnly: readOnly,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: _digits,
                maxLength: 3,
                validator: _range(50, 300),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                label: 'Diastolic (mmHg)',
                hint: '80',
                icon: Icons.monitor_heart_outlined,
                controller: c.dia,
                readOnly: readOnly,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: _digits,
                maxLength: 3,
                validator: _range(30, 200),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                label: 'Pulse (bpm)',
                hint: '72',
                icon: Icons.favorite_border_rounded,
                controller: c.pulse,
                readOnly: readOnly,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: _digits,
                maxLength: 3,
                validator: _range(20, 250),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                label: 'Respiration (/min)',
                hint: '16',
                icon: Icons.air_rounded,
                controller: c.resp,
                readOnly: readOnly,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: _digits,
                maxLength: 2,
                validator: _range(5, 60),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Temperature (°C)',
          hint: '36.5',
          icon: Icons.thermostat_rounded,
          controller: c.temp,
          readOnly: readOnly,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          inputFormatters: _decimal,
          maxLength: 5,
          validator: _range(30, 45),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                label: 'Height (cm)',
                hint: '165',
                icon: Icons.height_rounded,
                controller: c.height,
                readOnly: readOnly,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                inputFormatters: _decimal,
                maxLength: 5,
                validator: _range(30, 250),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                label: 'Weight (kg)',
                hint: '60',
                icon: Icons.monitor_weight_outlined,
                controller: c.weight,
                readOnly: readOnly,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                inputFormatters: _decimal,
                maxLength: 5,
                validator: _range(1, 300),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: color,
        ),
      ),
    );
  }
}
