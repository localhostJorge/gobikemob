import 'package:flutter/material.dart';

import '../../core/resident_visits.dart';
import 'app_colors.dart';
import 'skeletons.dart';
import 'ui_kit.dart';
import 'visit_details_screen.dart';
import 'visit_record.dart';
import 'vital_status.dart';

/// Read-only list of the patient's GoBiker check-ups, newest first.
class MedicalHistoryScreen extends StatelessWidget {
  const MedicalHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = ResidentVisits.instance;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: patientAppBar(context, 'Medical history'),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final firstLoad = !store.loaded;
            if (firstLoad && !store.loading && store.error != null) {
              return ErrorState(message: store.error!, onRetry: store.load);
            }
            return LoadSwitcher(
              loading: firstLoad && store.loading,
              skeleton: const MedicalHistorySkeleton(),
              child: RefreshIndicator(
                color: AppColors.red,
                onRefresh: store.load,
                child: _list(store),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _list(ResidentVisits store) {
    final sorted = [...store.visits]..sort((a, b) => b.date.compareTo(a.date));
    const padding = EdgeInsets.fromLTRB(Sp.gutter, Sp.sm, Sp.gutter, Sp.xl);

    final notice = store.error == null
        ? null
        : InlineNotice(
            message: "Couldn't refresh. Showing what was saved.",
            onAction: store.load,
          );

    if (sorted.isEmpty) {
      // Still scrollable, so pull-to-refresh works on the empty state too.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        children: [
          ?notice,
          const EmptyState(
            title: 'No records yet',
            message:
                'Your health records from GoBiker visits will appear here.',
          ),
        ],
      );
    }

    final earlier = sorted.skip(1).toList();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      children: [
        ?notice,
        _LatestCard(record: sorted.first),
        if (earlier.isNotEmpty) ...[
          const SizedBox(height: Sp.xl),
          const SectionHeader('Earlier visits'),
          CardGroup(
            dividerIndent: Sp.lg,
            children: [for (final v in earlier) _VisitRow(record: v)],
          ),
        ],
        const SizedBox(height: Sp.xl),
        const ScreeningNote(),
      ],
    );
  }
}

/// The most recent check-up, opened to its vitals.
class _LatestCard extends StatelessWidget {
  final VisitRecord record;
  const _LatestCard({required this.record});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VisitDetailsScreen(record: record)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Latest check-up', style: T.rowTitle)),
              Text(formatDate(record.date), style: T.meta),
            ],
          ),
          const SizedBox(height: Sp.xs),
          Text('${record.place} · ${record.gobikerName}', style: T.secondary),
          const SizedBox(height: Sp.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Stat(
                  label: 'Blood pressure',
                  value: '${record.systolic}/${record.diastolic}',
                  unit: 'mmHg',
                  footer: StatusBadge(
                    status: record.bpStatus,
                    adult: record.isAdult,
                  ),
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Pulse',
                  value: '${record.pulse}',
                  unit: 'bpm',
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Stat(
                  label: 'Temperature',
                  value: record.temperature.toStringAsFixed(1),
                  unit: '°C',
                ),
              ),
              Expanded(
                child: record.bloodSugar == null
                    ? const _Stat(
                        label: 'Blood sugar',
                        value: '—',
                        unit: 'Not tested',
                      )
                    : _Stat(
                        label: 'Blood sugar',
                        value: '${record.bloodSugar}',
                        unit: 'mg/dL',
                      ),
              ),
            ],
          ),
          const SizedBox(height: Sp.md),
          const Align(
            alignment: Alignment.centerRight,
            child: Text('See all details', style: T.meta),
          ),
        ],
      ),
    );
  }
}

/// One reading: a big value with its unit beside it.
class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Widget? footer;

  const _Stat({
    required this.label,
    required this.value,
    required this.unit,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: T.secondary),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            text: value,
            style: T.title,
            children: [TextSpan(text: ' $unit', style: T.secondary)],
          ),
        ),
        if (footer != null) ...[const SizedBox(height: Sp.xs), footer!],
      ],
    );
  }
}

class _VisitRow extends StatelessWidget {
  final VisitRecord record;
  const _VisitRow({required this.record});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VisitDetailsScreen(record: record)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.lg, 14, Sp.md, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(formatDate(record.date), style: T.rowTitle),
                  const SizedBox(height: 2),
                  Text(
                    '${record.place} · ${record.gobikerName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: T.secondary,
                  ),
                  const SizedBox(height: Sp.sm),
                  Text(
                    'BP ${record.systolic}/${record.diastolic} · '
                    'Pulse ${record.pulse}',
                    style: T.label,
                  ),
                  const SizedBox(height: Sp.xs),
                  StatusBadge(status: record.bpStatus, adult: record.isAdult),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
