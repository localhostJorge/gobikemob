import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Result of classifying a vital sign: a label, a color and an optional
/// patient-friendly note.
class VitalStatus {
  final String label;
  final Color color;
  final String? note;
  final bool urgent;

  const VitalStatus(this.label, this.color, {this.note, this.urgent = false});
}

/// All classification rules live here so they are easy to review and change.
///
/// Blood pressure follows the 2017 ACC/AHA adult guideline.
/// These are SCREENING labels only, not diagnoses.
class Vitals {
  static const _green = Color(0xFF2E9E5B);
  static const _amber = Color(0xFFD99A00);
  static const _orange = Color(0xFFF2711C);
  static const _red = Color(0xFFE53935);
  static const _darkRed = Color(0xFF8E0000);
  static const _blue = Color(0xFF3B5BDB);

  /// Thresholds below are for adults only.
  static bool isAdult(int age) => age >= 18;

  // ---------- Blood pressure ----------

  /// Returns an error message for impossible readings, or null if valid.
  /// Use this on the GoBiker's form before saving.
  static String? validateBp(int systolic, int diastolic) {
    if (systolic < 50 || systolic > 300) {
      return 'Systolic must be between 50 and 300';
    }
    if (diastolic < 30 || diastolic > 200) {
      return 'Diastolic must be between 30 and 200';
    }
    if (systolic <= diastolic) {
      return 'Systolic must be higher than diastolic';
    }
    return null;
  }

  /// The higher (worse) category of the two numbers wins.
  /// Returns null for minors or invalid readings (no label is shown).
  static VitalStatus? bp(int s, int d, int age) {
    if (!isAdult(age) || validateBp(s, d) != null) return null;

    if (s > 180 || d > 120) {
      return const VitalStatus(
        'Hypertensive Crisis',
        _darkRed,
        note: 'Very high reading. Seek medical care right away.',
        urgent: true,
      );
    }
    if (s >= 140 || d >= 90) {
      return const VitalStatus(
        'High (Stage 2)',
        _red,
        note: 'Well above the normal range. Please see a health worker soon.',
      );
    }
    if (s >= 130 || d >= 80) {
      return const VitalStatus(
        'High (Stage 1)',
        _orange,
        note: 'Above the normal range. Please consult a health worker.',
      );
    }
    if (s >= 120) {
      return const VitalStatus(
        'Elevated',
        _amber,
        note: 'Slightly above normal. Healthy habits can help.',
      );
    }
    if (s < 90 || d < 60) {
      return const VitalStatus(
        'Low',
        _blue,
        note: 'Low readings matter mostly if you feel dizzy or faint.',
      );
    }
    return const VitalStatus('Normal', _green);
  }

  // ---------- Other vitals (adults only, soft wording) ----------

  static VitalStatus? pulse(int bpm, int age) {
    if (!isAdult(age)) return null;
    if (bpm < 60) return const VitalStatus('Below typical range', _blue);
    if (bpm > 100) return const VitalStatus('Above typical range', _orange);
    return const VitalStatus('Typical range', _green);
  }

  static VitalStatus? respiration(int perMin, int age) {
    if (!isAdult(age)) return null;
    if (perMin < 12) return const VitalStatus('Below typical range', _blue);
    if (perMin > 20) return const VitalStatus('Above typical range', _orange);
    return const VitalStatus('Typical range', _green);
  }

  static VitalStatus? temperature(double c, int age) {
    if (!isAdult(age)) return null;
    if (c < 36.1) return const VitalStatus('Below typical range', _blue);
    if (c <= 37.2) return const VitalStatus('Typical range', _green);
    if (c < 38.0) return const VitalStatus('Slightly raised', _amber);
    return const VitalStatus('Fever', _orange);
  }

  /// Asia-Pacific BMI cutoffs, which suit Filipino adults better than the
  /// standard WHO cutoffs.
  static VitalStatus? bmi(double bmi, int age) {
    if (!isAdult(age)) return null;
    if (bmi < 18.5) return const VitalStatus('Underweight range', _blue);
    if (bmi < 23) return const VitalStatus('Typical range', _green);
    if (bmi < 25) return const VitalStatus('Overweight range', _amber);
    return const VitalStatus('Obese range', _orange);
  }
}

class StatusChip extends StatelessWidget {
  final VitalStatus status;
  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: status.color,
        ),
      ),
    );
  }
}

/// Shows the chip when a status exists. For minors (no status because the
/// adult ranges don't apply) it shows a neutral hint instead.
class StatusBadge extends StatelessWidget {
  final VitalStatus? status;
  final bool adult;
  const StatusBadge({super.key, required this.status, required this.adult});

  @override
  Widget build(BuildContext context) {
    if (status != null) return StatusChip(status: status!);
    if (!adult) {
      return const Text('Ask a health worker',
          style: TextStyle(fontSize: 11.5, color: AppColors.textMuted));
    }
    return const SizedBox.shrink();
  }
}

class ScreeningNote extends StatelessWidget {
  const ScreeningNote({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        'These labels are screening readings, not a diagnosis. '
        'Please consult a health worker about your results.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
      ),
    );
  }
}