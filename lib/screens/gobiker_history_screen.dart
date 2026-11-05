import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/gobiker_history.dart';
import '../core/theme.dart';
import '../widgets/confirm_modal.dart';
import 'view_patient_screen.dart';

enum _Filter { all, rondas, checkups, visits, sos }

extension on _Filter {
  String get label => switch (this) {
    _Filter.all => 'All',
    _Filter.rondas => 'Rondas',
    _Filter.checkups => 'Check-ups',
    _Filter.visits => 'Home visits',
    _Filter.sos => 'SOS',
  };

  bool matches(HistoryKind kind) => switch (this) {
    _Filter.all => true,
    _Filter.rondas => kind == HistoryKind.ronda,
    _Filter.checkups => kind == HistoryKind.checkup,
    _Filter.visits => kind == HistoryKind.visit,
    _Filter.sos => kind == HistoryKind.sos,
  };
}

/// Everything this GoBiker has finished, newest first and grouped by day: rondas, the check-ups
/// they recorded, home visits and the emergencies they answered. Each row opens its details;
/// Clear hides what is there now (on this phone only).
class GobikerHistoryScreen extends StatefulWidget {
  const GobikerHistoryScreen({super.key});

  @override
  State<GobikerHistoryScreen> createState() => _GobikerHistoryScreenState();
}

class _GobikerHistoryScreenState extends State<GobikerHistoryScreen> {
  _Filter _filter = _Filter.all;

  GobikerHistory get _history => GobikerHistory.instance;

  @override
  void initState() {
    super.initState();
    // After the first frame: loading tells listeners to rebuild, and none may be told mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _history.load();
    });
  }

  Future<void> _clear() async {
    final ok = await ConfirmModal.show(
      context: context,
      icon: Icons.delete_outline_rounded,
      color: AppTheme.errorRed,
      title: 'Clear history?',
      description:
          'This hides everything shown here on this phone. Nothing is deleted: '
          'your check-ups stay in Patients, and visits and SOS stay on the '
          'server. Anything new will show up again.',
      confirmText: 'Clear',
      onConfirm: () {},
    );
    if (ok != true || !mounted) return;
    await _history.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('History cleared.')));
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(DateTime(d.year, d.month, d.day)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('MMMM d, yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return ListenableBuilder(
      listenable: _history,
      builder: (context, _) {
        final all = _history.entries();
        final items = all.where((e) => _filter.matches(e.kind)).toList();
        final firstLoad = !_history.loaded;

        return Scaffold(
          appBar: AppBar(
            scrolledUnderElevation: 0,
            centerTitle: true,
            title: const Text(
              'History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            actions: [
              if (all.isNotEmpty)
                TextButton.icon(
                  onPressed: _clear,
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  label: const Text('Clear'),
                ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                _filters(theme),
                Expanded(
                  child: firstLoad && _history.loading
                      ? const Center(child: CircularProgressIndicator())
                      : firstLoad && _history.error != null
                      ? _problem(theme, muted)
                      : _list(theme, muted, items),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _filters(ThemeData theme) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          for (final f in _Filter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(f.label),
                selected: _filter == f,
                showCheckmark: false,
                onSelected: (_) => setState(() => _filter = f),
              ),
            ),
        ],
      ),
    );
  }

  Widget _problem(ThemeData theme, Color muted) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: muted),
            const SizedBox(height: 12),
            const Text(
              "Couldn't load your history",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              _history.error ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _history.load,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(ThemeData theme, Color muted, List<HistoryEntry> items) {
    // One card per day.
    final days = <(String, List<HistoryEntry>)>[];
    for (final item in items) {
      final label = _dayLabel(item.time);
      if (days.isEmpty || days.last.$1 != label) {
        days.add((label, [item]));
      } else {
        days.last.$2.add(item);
      }
    }

    return RefreshIndicator(
      onRefresh: _history.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (_history.partial)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Some of your history could not be loaded. Pull down to try again.',
                style: TextStyle(fontSize: 13, color: muted),
              ),
            ),
          if (items.isEmpty)
            _empty(muted)
          else
            for (final (label, dayItems) in days) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w700,
                    color: muted,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < dayItems.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: theme.dividerColor),
                      _HistoryRow(entry: dayItems[i]),
                    ],
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }

  Widget _empty(Color muted) {
    final text = switch (_filter) {
      _Filter.rondas => 'Rondas you finish will show here.',
      _Filter.checkups => 'Check-ups you record will show here.',
      _Filter.visits => 'Home visits you do or answer will show here.',
      _Filter.sos => 'Emergencies you answer will show here.',
      _Filter.all =>
        'Rondas, check-ups, home visits and SOS you finish will show here.',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.history_rounded, size: 52, color: muted),
          const SizedBox(height: 12),
          const Text(
            'Nothing here yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: muted),
          ),
        ],
      ),
    );
  }
}

({IconData icon, Color color}) _look(HistoryKind kind) => switch (kind) {
  HistoryKind.ronda => (
    icon: Icons.directions_bike_rounded,
    color: AppTheme.blue,
  ),
  HistoryKind.checkup => (
    icon: Icons.favorite_border_rounded,
    color: AppTheme.successGreen,
  ),
  HistoryKind.visit => (icon: Icons.home_outlined, color: AppTheme.orange),
  HistoryKind.sos => (icon: Icons.sos_rounded, color: AppTheme.errorRed),
};

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final HistoryEntry entry;

  void _open(BuildContext context) {
    final checkup = entry.checkup;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => checkup != null
            ? ViewPatientScreen(patient: checkup)
            : GobikerHistoryDetailsScreen(entry: entry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final look = _look(entry.kind);
    final ok = entry.status == 'Done' || entry.status == 'Resolved';

    return InkWell(
      onTap: () => _open(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: look.color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(look.icon, size: 20, color: look.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, height: 1.35, color: muted),
                  ),
                  if (entry.status != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Words and an icon: the outcome is never only a colour.
                        Icon(
                          ok
                              ? Icons.check_circle_rounded
                              : Icons.remove_circle_outline_rounded,
                          size: 14,
                          color: ok ? AppTheme.successGreen : muted,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            entry.status!,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: ok ? AppTheme.successGreen : muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('h:mm a').format(entry.time),
              style: TextStyle(fontSize: 12, color: muted),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: muted),
          ],
        ),
      ),
    );
  }
}

/// The details of one History row that has no screen of its own (a ronda, a home visit, an
/// emergency). Check-ups open the existing patient screen instead.
class GobikerHistoryDetailsScreen extends StatelessWidget {
  const GobikerHistoryDetailsScreen({super.key, required this.entry});

  final HistoryEntry entry;

  List<(String, String)> _facts() {
    final fmt = DateFormat('MMMM d, yyyy · h:mm a');
    String when(DateTime? d) => d == null ? '' : fmt.format(d);

    final r = entry.ronda;
    if (r != null) {
      return [
        ('Barangay', '${r['barangay']}'),
        ('Date', '${r['date']}'),
        ('Started', '${r['startTime']}'),
        ('Ended', '${r['endTime']}'),
        ('Patients', '${r['patientsCount']}'),
        ('Distance', '${(r['distance'] as double).toStringAsFixed(1)} km'),
      ];
    }

    final v = entry.visit;
    if (v != null) {
      return [
        ('Outcome', entry.status ?? v.statusLabel),
        ('Resident', v.residentName ?? 'Resident'),
        if ((v.residentMobile ?? '').isNotEmpty) ('Mobile', v.residentMobile!),
        ('Where', '${v.address}, ${v.barangay}'),
        (
          'Asked for',
          '${DateFormat('MMMM d, yyyy').format(v.preferredDate)} · ${v.windowLabel}',
        ),
        ('Reason', v.reason),
        if (v.status == 'declined')
          ('Your message', v.declineNote ?? 'No message was sent.'),
        if (v.completedAt != null) ('Done', when(v.completedAt)),
        if (v.status != 'completed') ('Last changed', when(v.changedAt)),
        ('Requested', when(v.createdAt)),
      ];
    }

    final s = entry.sos!;
    return [
      ('Outcome', entry.status ?? 'Resolved'),
      ('Resident', s.residentName),
      ('Where', s.place.isEmpty ? 'No location given' : s.place),
      if (s.description != null) ('What happened', s.description!),
      ('Sent', when(s.createdAt)),
      if (s.respondedAt != null) ('Answered', when(s.respondedAt)),
      if (s.resolvedAt != null)
        (s.cancelled ? 'Cancelled' : 'Resolved', when(s.resolvedAt)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final look = _look(entry.kind);
    final facts = _facts();

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(switch (entry.kind) {
          HistoryKind.ronda => 'Ronda',
          HistoryKind.visit => 'Home visit',
          HistoryKind.sos => 'Emergency',
          HistoryKind.checkup => 'Check-up',
        }, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: look.color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(look.icon, color: look.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  for (var i = 0; i < facts.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: theme.dividerColor),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 104,
                            child: Text(
                              facts[i].$1,
                              style: TextStyle(fontSize: 13, color: muted),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              facts[i].$2,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
