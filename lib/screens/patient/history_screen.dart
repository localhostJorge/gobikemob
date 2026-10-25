import 'package:flutter/material.dart';

import '../../core/appointments.dart';
import '../../core/auth_service.dart';
import '../../core/resident_sos.dart';
import '../../core/resident_visits.dart';
import 'app_colors.dart';
import 'patient_store.dart';
import 'safety_tab.dart' show sosStatusStyle;
import 'visit_details_screen.dart';
import 'visit_record.dart';
import 'visits_status.dart';

enum _Filter { all, checkups, visits, sos }

extension on _Filter {
  String get label => switch (this) {
    _Filter.all => 'All',
    _Filter.checkups => 'Check-ups',
    _Filter.visits => 'Home visits',
    _Filter.sos => 'SOS',
  };
}

enum _Kind { checkup, checkupUpdated, visit, sos }

class _Item {
  const _Item({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.time,
    this.status,
    this.statusColor,
    this.visit,
  });

  final _Kind kind;
  final String title;
  final String subtitle;
  final DateTime time;
  final String? status;
  final Color? statusColor;
  final VisitRecord? visit;
}

/// Everything on the resident's account, newest first and grouped by day:
/// check-ups, home visits and SOS requests (all from the server).
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  _Filter _filter = _Filter.all;
  bool _clearing = false;

  ResidentVisits get _visits => ResidentVisits.instance;

  List<_Item> _items() {
    final items = <_Item>[
      for (final s in ResidentSos.instance.requests)
        _Item(
          kind: _Kind.sos,
          title: 'SOS request',
          subtitle: '${s.barangay} · ${s.landmark}',
          time: s.createdAt,
          status: sosStatusStyle(s).label,
          statusColor: sosStatusStyle(s).color,
        ),
      for (final a in ResidentAppointments.instance.appointments)
        _Item(
          kind: _Kind.visit,
          title: 'Home visit request',
          subtitle: 'For ${formatDate(a.preferredDate)} · ${a.barangay}',
          time: a.createdAt,
          status: a.statusLabel,
          statusColor: a.isOpen ? AppColors.orange : AppColors.textMuted,
        ),
      for (final v in _visits.visits) ...[
        _Item(
          kind: _Kind.checkup,
          title: 'Check-up',
          subtitle: 'BP ${v.systolic}/${v.diastolic} · ${v.place}',
          time: v.date,
          visit: v,
        ),
        if (v.updatedAt != null)
          _Item(
            kind: _Kind.checkupUpdated,
            title: 'Check-up updated',
            subtitle: '${formatDate(v.date)} visit · ${v.place}',
            time: v.updatedAt!,
            visit: v,
          ),
      ],
    ];
    items.sort((a, b) => b.time.compareTo(a.time));
    return items;
  }

  bool _matches(_Item i) => switch (_filter) {
    _Filter.all => true,
    _Filter.checkups =>
      i.kind == _Kind.checkup || i.kind == _Kind.checkupUpdated,
    _Filter.visits => i.kind == _Kind.visit,
    _Filter.sos => i.kind == _Kind.sos,
  };

  /// Finished SOS requests and closed home visits: what "Clear" removes.
  bool get _hasClearable =>
      ResidentSos.instance.requests.any((s) => !s.isOpen) ||
      ResidentAppointments.instance.appointments.any((a) => !a.isOpen);

  Future<void> _refresh() => Future.wait([
    _visits.load(),
    ResidentSos.instance.load(),
    ResidentAppointments.instance.load(),
  ]);

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text(
          'This removes finished SOS requests and closed home visits from '
          'your history.\n\nYour check-ups stay, because they are your '
          'medical record. Requests that are still open also stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Clear',
              style: TextStyle(
                color: AppColors.red,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _clearing = true);
    final res = await AuthService.instance.callAuthed(
      'POST',
      '/resident/history/clear',
    );
    if (res.ok) {
      await PatientStore.instance.clearActivities(); // old entries on the phone
      await Future.wait([
        ResidentSos.instance.load(),
        ResidentAppointments.instance.load(),
      ]);
    }
    if (!mounted) return;
    setState(() => _clearing = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            res.ok ? 'History cleared.' : "Couldn't clear: ${res.message}",
          ),
        ),
      );
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(DateTime(d.year, d.month, d.day)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return formatDate(d);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _visits,
        ResidentSos.instance,
        ResidentAppointments.instance,
      ]),
      builder: (context, _) {
        final items = _items().where(_matches).toList();
        final firstLoad = !_visits.loaded;

        // One card per day.
        final days = <(String, List<_Item>)>[];
        for (final item in items) {
          final label = _dayLabel(item.time);
          if (days.isEmpty || days.last.$1 != label) {
            days.add((label, [item]));
          } else {
            days.last.$2.add(item);
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'History',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  if (_hasClearable)
                    TextButton.icon(
                      onPressed: _clearing ? null : _clear,
                      icon: _clearing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline_rounded, size: 20),
                      label: const Text('Clear'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                        minimumSize: const Size(48, 48),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 48,
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
                        selectedColor: AppColors.textDark,
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: _filter == f
                              ? AppColors.textDark
                              : Colors.grey.shade300,
                        ),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: _filter == f
                              ? Colors.white
                              : AppColors.textDark,
                        ),
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: firstLoad && _visits.loading
                  ? const VisitsLoading()
                  : firstLoad && _visits.error != null && items.isEmpty
                  ? VisitsLoadError(message: _visits.error!, onRetry: _refresh)
                  : RefreshIndicator(
                      color: AppColors.red,
                      onRefresh: _refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          if (_visits.error != null)
                            VisitsErrorBanner(
                              message: _visits.error!,
                              onRetry: _refresh,
                            ),
                          if (items.isEmpty)
                            _Empty(filter: _filter)
                          else
                            for (final (label, dayItems) in days) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                              _DayCard(items: dayItems),
                            ],
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// The entries of one day in a single card, separated by thin lines.
class _DayCard extends StatelessWidget {
  const _DayCard({required this.items});
  final List<_Item> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECE7E7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: 52, color: Color(0xFFF0ECEC)),
            _Row(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item});
  final _Item item;

  ({IconData icon, Color color}) get _look => switch (item.kind) {
    _Kind.sos => (icon: Icons.sos_rounded, color: AppColors.red),
    _Kind.visit => (icon: Icons.home_outlined, color: AppColors.orange),
    _Kind.checkup => (
      icon: Icons.favorite_border_rounded,
      color: AppColors.blue,
    ),
    _Kind.checkupUpdated => (icon: Icons.edit_outlined, color: AppColors.blue),
  };

  @override
  Widget build(BuildContext context) {
    final visit = item.visit;
    final look = _look;

    return InkWell(
      onTap: visit == null
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VisitDetailsScreen(record: visit),
              ),
            ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(look.icon, size: 22, color: look.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppColors.textMuted,
                    ),
                  ),
                  if (item.status != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.status!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: item.statusColor ?? AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatTime(item.time),
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            if (visit != null)
              const Padding(
                padding: EdgeInsets.only(left: 2),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.filter});
  final _Filter filter;

  @override
  Widget build(BuildContext context) {
    final text = switch (filter) {
      _Filter.checkups => 'Check-ups a GoBiker records for you will show here.',
      _Filter.visits => 'Home visits you request will show here.',
      _Filter.sos => 'SOS requests you send will show here.',
      _Filter.all => 'Check-ups, home visits and SOS requests will show here.',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
      child: Column(
        children: [
          const Text(
            'Nothing here yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
