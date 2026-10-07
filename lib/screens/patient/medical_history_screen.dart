import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'visit_details_screen.dart';
import 'visit_record.dart';
import 'vital_status.dart';

/// Read-only list of the patient's GoBiker check-ups, newest first.
class MedicalHistoryScreen extends StatelessWidget {
  final List<VisitRecord> visits;

  const MedicalHistoryScreen({super.key, required this.visits});

  @override
  Widget build(BuildContext context) {
    final sorted = [...visits]..sort((a, b) => b.date.compareTo(a.date));

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
          'Medical History',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark),
        ),
      ),
      body: SafeArea(
        child: sorted.isEmpty
            ? const _EmptyState()
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _LatestCard(record: sorted.first),
                  const SizedBox(height: 22),
                  const Text('Visit History',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark)),
                  const SizedBox(height: 10),
                  for (final v in sorted)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _VisitCard(record: v),
                    ),
                  const SizedBox(height: 6),
                  const ScreeningNote(),
                ],
              ),
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

class _LatestCard extends StatelessWidget {
  final VisitRecord record;
  const _LatestCard({required this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_heart_outlined,
                  color: AppColors.red, size: 18),
              const SizedBox(width: 6),
              const Text('LATEST VITALS',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: AppColors.red)),
              const Spacer(),
              Text(formatDate(record.date),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Stat(
                  label: 'Blood Pressure',
                  value: '${record.systolic}/${record.diastolic}',
                  footer: StatusBadge(
                      status: record.bpStatus, adult: record.isAdult),
                ),
              ),
              Expanded(
                child: _Stat(label: 'Pulse', value: '${record.pulse} bpm'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Stat(
                  label: 'Temperature',
                  value: '${record.temperature.toStringAsFixed(1)} °C',
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Weight',
                  value: '${record.weightKg.toStringAsFixed(1)} kg',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Widget? footer;

  const _Stat({required this.label, required this.value, this.footer});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark)),
        if (footer != null) ...[
          const SizedBox(height: 4),
          footer!,
        ],
      ],
    );
  }
}

class _VisitCard extends StatelessWidget {
  final VisitRecord record;
  const _VisitCard({required this.record});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: _cardDecoration(),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VisitDetailsScreen(record: record),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.redSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text('${record.date.day}',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.red)),
                      Text(monthShort(record.date),
                          style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.red)),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(record.place,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark)),
                      const SizedBox(height: 2),
                      Text(
                          '${formatTime(record.date)} · ${record.gobikerName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMuted)),
                      const SizedBox(height: 6),
                      Text(
                        'BP ${record.systolic}/${record.diastolic} · '
                        'Pulse ${record.pulse}',
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark),
                      ),
                      const SizedBox(height: 6),
                      StatusBadge(
                          status: record.bpStatus, adult: record.isAdult),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_rounded,
                size: 56, color: AppColors.textMuted),
            SizedBox(height: 14),
            Text('No records yet',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark)),
            SizedBox(height: 6),
            Text(
              'Your health records from GoBiker visits will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}