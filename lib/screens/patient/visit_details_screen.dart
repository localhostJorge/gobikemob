import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'visit_record.dart';
import 'vital_status.dart';

/// Full, read-only details of one GoBiker check-up.
class VisitDetailsScreen extends StatelessWidget {
  final VisitRecord record;

  const VisitDetailsScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final bp = record.bpStatus;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Visit Details',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _visitHeader(),
            if (bp != null && bp.urgent) ...[
              const SizedBox(height: 14),
              _urgentBanner(bp.note ?? ''),
            ],
            const SizedBox(height: 14),
            _Section(
              title: 'Patient Information',
              children: [
                _InfoRow('Full Name', record.patientName),
                _InfoRow('Address', record.address),
                _InfoRow('Contact Number', record.contactNumber),
                _InfoRow('Age', '${record.age}'),
              ],
            ),
            const SizedBox(height: 14),
            _Section(
              title: 'Vitals',
              children: [
                _VitalRow(
                  label: 'Blood Pressure',
                  value: '${record.systolic}/${record.diastolic} mmHg',
                  status: bp,
                  adult: record.isAdult,
                ),
                _VitalRow(
                  label: 'Pulse',
                  value: '${record.pulse} bpm',
                  status: record.pulseStatus,
                  adult: record.isAdult,
                ),
                _VitalRow(
                  label: 'Respiration',
                  value: '${record.respiration} /min',
                  status: record.respirationStatus,
                  adult: record.isAdult,
                ),
                _VitalRow(
                  label: 'Temperature',
                  value: '${record.temperature.toStringAsFixed(1)} °C',
                  status: record.temperatureStatus,
                  adult: record.isAdult,
                ),
                _VitalRow(
                  label: 'Height',
                  value: '${record.heightCm.toStringAsFixed(0)} cm',
                ),
                _VitalRow(
                  label: 'Weight',
                  value: '${record.weightKg.toStringAsFixed(1)} kg',
                ),
                _VitalRow(
                  label: 'BMI',
                  value: record.bmi.toStringAsFixed(1),
                  status: record.bmiStatus,
                  adult: record.isAdult,
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _Section(
              title: 'GoBiker Remarks',
              children: [
                Text(
                  record.remarks.trim().isEmpty
                      ? 'No remarks were recorded for this visit.'
                      : record.remarks,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: record.remarks.trim().isEmpty
                        ? AppColors.textMuted
                        : AppColors.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const ScreeningNote(),
          ],
        ),
      ),
    );
  }

  Widget _visitHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.redSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.event_note_rounded, color: AppColors.red),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${formatDate(record.date)} · ${formatTime(record.date)}',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark),
                ),
                const SizedBox(height: 2),
                Text(record.place,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textMuted)),
                Text('Recorded by ${record.gobikerName}',
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _urgentBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDE8E8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.red, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9B1C1C))),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration() => BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.textMuted)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark)),
          ),
        ],
      ),
    );
  }
}

class _VitalRow extends StatelessWidget {
  final String label;
  final String value;
  final VitalStatus? status;
  final bool adult;
  final bool isLast;
  final bool showBadge;

  const _VitalRow({
    required this.label,
    required this.value,
    this.status,
    this.adult = true,
    this.isLast = false,
  }) : showBadge = true;

  @override
  Widget build(BuildContext context) {
    final hasStatusArea = status != null || !adult;
    // Height and weight have no status; don't show the minors hint for them.
    final showHint = status != null || (!adult && _needsHint);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textMuted)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(value,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark)),
                  if (hasStatusArea && showHint) ...[
                    const SizedBox(height: 4),
                    StatusBadge(status: status, adult: adult),
                  ],
                ],
              ),
            ],
          ),
          if (status?.note != null) ...[
            const SizedBox(height: 6),
            Text(status!.note!,
                style: const TextStyle(
                    fontSize: 12, height: 1.35, color: AppColors.textMuted)),
          ],
        ],
      ),
    );
  }

  // Height and weight rows never carry a status.
  bool get _needsHint => label != 'Height' && label != 'Weight';
}