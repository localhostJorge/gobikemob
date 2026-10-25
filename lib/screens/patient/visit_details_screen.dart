import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'ui_kit.dart';
import 'visit_record.dart';
import 'vital_status.dart';

/// Full, read-only details of one GoBiker check-up.
class VisitDetailsScreen extends StatelessWidget {
  final VisitRecord record;

  const VisitDetailsScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final bp = record.bpStatus;
    final noRemarks = record.remarks.trim().isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: patientAppBar(context, 'Check-up'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Sp.gutter,
            Sp.sm,
            Sp.gutter,
            Sp.xl,
          ),
          children: [
            // Who, where and when, as a heading rather than a card.
            Text(formatDate(record.date), style: T.title),
            const SizedBox(height: Sp.xs),
            Text(
              '${formatTime(record.date)} · ${record.place}',
              style: T.secondary,
            ),
            Text('Recorded by ${record.gobikerName}', style: T.secondary),
            if (bp != null && bp.urgent) ...[
              const SizedBox(height: Sp.lg),
              _UrgentNote(message: bp.note ?? ''),
            ],
            const SizedBox(height: Sp.xl),
            const SectionHeader('Vitals'),
            CardGroup(
              children: [
                _VitalRow(
                  label: 'Blood pressure',
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
                  label: 'Blood sugar',
                  value: record.bloodSugar == null
                      ? 'Not tested'
                      : '${record.bloodSugar} mg/dL',
                  status: record.bloodSugarStatus,
                  adult: record.isAdult,
                ),
              ],
            ),
            const SizedBox(height: Sp.xl),
            const SectionHeader('GoBiker remarks'),
            AppCard(
              child: Text(
                noRemarks
                    ? 'No remarks were recorded for this visit.'
                    : record.remarks,
                style: noRemarks ? T.secondary : T.body,
              ),
            ),
            const SizedBox(height: Sp.xl),
            const SectionHeader('Patient information'),
            CardGroup(
              children: [
                _InfoRow('Full name', record.patientName),
                _InfoRow('Address', record.address),
                _InfoRow('Contact number', record.contactNumber),
                _InfoRow('Age', '${record.age}'),
              ],
            ),
            const SizedBox(height: Sp.xl),
            const ScreeningNote(),
          ],
        ),
      ),
    );
  }
}

class _UrgentNote extends StatelessWidget {
  const _UrgentNote({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(Sp.md),
        decoration: BoxDecoration(
          color: AppColors.redSoft,
          borderRadius: BorderRadius.circular(Rd.control),
          border: Border.all(color: AppColors.redText.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.redText,
              size: 22,
            ),
            const SizedBox(width: Sp.md),
            Expanded(
              child: Text(
                message,
                style: T.label.copyWith(color: const Color(0xFF8E0000)),
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: T.secondary)),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: T.body.copyWith(fontWeight: FontWeight.w600),
            ),
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

  const _VitalRow({
    required this.label,
    required this.value,
    this.status,
    this.adult = true,
  });

  // A blood sugar that was not tested never carries a status.
  bool get _needsHint => value != 'Not tested';

  @override
  Widget build(BuildContext context) {
    // A reading that was not taken has no status; don't show the minors hint for it.
    final showHint = status != null || (!adult && _needsHint);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(label, style: T.secondary)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(value, style: T.rowTitle),
                  if (showHint) ...[
                    const SizedBox(height: Sp.xs),
                    StatusBadge(status: status, adult: adult),
                  ],
                ],
              ),
            ],
          ),
          if (status?.note != null) ...[
            const SizedBox(height: Sp.sm),
            Text(status!.note!, style: T.meta),
          ],
        ],
      ),
    );
  }
}
