import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'patient_store.dart';
import 'patient_ui.dart';
import 'visit_details_screen.dart';
import 'visit_record.dart';

enum _Filter { all, checkups, appointments, sos }

extension on _Filter {
  String get label => switch (this) {
        _Filter.all => 'All',
        _Filter.checkups => 'Check-ups',
        _Filter.appointments => 'Appointments',
        _Filter.sos => 'SOS',
      };
}

class _Item {
  final ActivityType type;
  final String title;
  final String subtitle;
  final DateTime time;
  final VisitRecord? visit;

  const _Item(this.type, this.title, this.subtitle, this.time, {this.visit});
}

/// Everything that happened on the patient's account, newest first:
/// check-ups (and updates), appointments and SOS requests.
class HistoryTab extends StatefulWidget {
  final List<VisitRecord> visits;

  const HistoryTab({super.key, required this.visits});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  _Filter _filter = _Filter.all;

  List<_Item> _items() {
    final items = <_Item>[
      for (final a in PatientStore.instance.activities)
        _Item(a.type, a.title, a.subtitle, a.time),
      for (final v in widget.visits) ...[
        _Item(
          ActivityType.checkup,
          'Check-up recorded',
          '${v.place} · BP ${v.systolic}/${v.diastolic}',
          v.date,
          visit: v,
        ),
        if (v.updatedAt != null)
          _Item(
            ActivityType.checkupUpdated,
            'Check-up updated',
            '${v.place} · ${formatDate(v.date)} visit',
            v.updatedAt!,
            visit: v,
          ),
      ],
    ];
    items.sort((a, b) => b.time.compareTo(a.time));
    return items;
  }

  bool _matches(_Item i) => switch (_filter) {
        _Filter.all => true,
        _Filter.checkups => i.type == ActivityType.checkup ||
            i.type == ActivityType.checkupUpdated,
        _Filter.appointments => i.type == ActivityType.appointment,
        _Filter.sos => i.type == ActivityType.sos,
      };

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return formatDate(d);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PatientStore.instance,
      builder: (context, _) {
        final items = _items().where(_matches).toList();

        final children = <Widget>[];
        String? lastLabel;
        for (final item in items) {
          final label = _dayLabel(item.time);
          if (label != lastLabel) {
            children.add(Padding(
              padding: EdgeInsets.fromLTRB(4, lastLabel == null ? 4 : 14, 4, 8),
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted)),
            ));
            lastLabel = label;
          }
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Tile(item: item),
          ));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Text('History',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark)),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final f in _Filter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f.label),
                        selected: _filter == f,
                        showCheckmark: false,
                        selectedColor: AppColors.redSoft,
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: _filter == f
                              ? AppColors.red
                              : Colors.grey.shade300,
                        ),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: _filter == f
                              ? AppColors.red
                              : AppColors.textMuted,
                        ),
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: items.isEmpty
                  ? const _Empty()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: children,
                    ),
            ),
          ],
        );
      },
    );
  }
}

({IconData icon, Color color}) _style(ActivityType t) => switch (t) {
      ActivityType.sos => (icon: Icons.emergency_rounded, color: AppColors.red),
      ActivityType.appointment =>
        (icon: Icons.calendar_month_rounded, color: AppColors.orange),
      ActivityType.checkup =>
        (icon: Icons.monitor_heart_outlined, color: AppColors.blue),
      ActivityType.checkupUpdated =>
        (icon: Icons.edit_note_rounded, color: AppColors.blue),
    };

class _Tile extends StatelessWidget {
  final _Item item;
  const _Tile({required this.item});

  @override
  Widget build(BuildContext context) {
    final s = _style(item.type);
    final visit = item.visit;

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: cardDecoration(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: visit == null
              ? null
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VisitDetailsScreen(record: visit),
                    ),
                  ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: s.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(s.icon, color: s.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark)),
                      if (item.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(item.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textMuted)),
                      ],
                      const SizedBox(height: 4),
                      Text(formatTime(item.time),
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                if (visit != null)
                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 56, color: AppColors.textMuted),
            SizedBox(height: 14),
            Text('Nothing here yet',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark)),
            SizedBox(height: 6),
            Text(
              'Check-ups, appointments and SOS requests will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}