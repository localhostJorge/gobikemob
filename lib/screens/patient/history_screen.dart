import 'package:flutter/material.dart';

import '../../core/appointments.dart';
import '../../core/auth_service.dart';
import '../../core/resident_sos.dart';
import '../../core/resident_visits.dart';
import 'app_colors.dart';
import 'patient_store.dart';
import 'safety_tab.dart' show sosStatusStyle;
import 'skeletons.dart';
import 'sos_details_screen.dart';
import 'ui_kit.dart';
import 'visit_details_screen.dart';
import 'visit_record.dart';
import 'visit_request_screen.dart';

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
    this.page,
    this.unseen = false,
  });

  final _Kind kind;
  final String title;
  final String subtitle;
  final DateTime time;
  final String? status;
  final Color? statusColor;
  final VisitRecord? visit;

  /// Opens this item's details, when it has some.
  final WidgetBuilder? page;

  /// An answer from the GoBiker that the person has not opened yet.
  final bool unseen;
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
          subtitle: s.place,
          time: s.createdAt,
          status: sosStatusStyle(s, context.pal).label,
          statusColor: sosStatusStyle(s, context.pal).color,
          page: (_) => SosDetailsScreen(sosId: s.id),
        ),
      // A request still waiting for an answer is on Home, under Map. History holds what has
      // happened to it: accepted, declined, done or cancelled.
      for (final a in ResidentAppointments.instance.appointments)
        if (a.status != 'pending')
          _Item(
            kind: _Kind.visit,
            title: 'Home visit request',
            subtitle: 'For ${formatDate(a.preferredDate)} · ${a.barangay}',
            time: a.changedAt, // when it was answered, not when it was sent
            status: a.statusLabel,
            statusColor: a.isOpen ? context.pal.orangeText : context.pal.muted,
            page: (_) => VisitRequestScreen(appointmentId: a.id),
            unseen: PatientStore.instance.isVisitUnseen(a),
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
    final ok = await showConfirm(
      context,
      title: 'Clear history?',
      message:
          'This removes finished SOS requests and closed home visits from '
          'your history.\n\nYour check-ups stay, because they are your '
          'medical record. Requests that are still open also stay.',
      confirmLabel: 'Clear',
      destructive: true,
    );
    if (!ok || !mounted) return;

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
        PatientStore.instance, // which answers were opened
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

        Widget body;
        if (firstLoad && _visits.error != null && items.isEmpty) {
          body = ErrorState(message: _visits.error!, onRetry: _refresh);
        } else {
          body = RefreshIndicator(
            color: AppColors.red,
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                Sp.gutter,
                Sp.sm,
                Sp.gutter,
                Sp.xl,
              ),
              children: [
                if (_visits.error != null)
                  InlineNotice(
                    message: "Couldn't refresh. Showing what was saved.",
                    onAction: _refresh,
                  ),
                if (items.isEmpty)
                  _Empty(filter: _filter)
                else
                  for (final (label, dayItems) in days) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, Sp.md, 4, Sp.sm),
                      child: Text(
                        label,
                        style: T.secondary
                            .muted(context)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    CardGroup(
                      dividerIndent: 52,
                      children: [for (final i in dayItems) _Row(item: i)],
                    ),
                  ],
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TabHeader(
              'History',
              trailing: _hasClearable
                  ? QuietButton(
                      label: 'Clear',
                      icon: Icons.delete_outline_rounded,
                      onPressed: _clearing ? null : _clear,
                    )
                  : null,
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Sp.gutter),
                children: [
                  for (final f in _Filter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: Sp.sm),
                      child: ChoiceChip(
                        label: Text(f.label),
                        selected: _filter == f,
                        showCheckmark: false,
                        selectedColor: context.pal.ink,
                        backgroundColor: context.pal.card,
                        side: BorderSide(
                          color: _filter == f
                              ? context.pal.ink
                              : context.pal.line,
                        ),
                        labelStyle: T.label.copyWith(
                          color: _filter == f
                              ? context.pal.card
                              : context.pal.ink,
                        ),
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: LoadSwitcher(
                loading: firstLoad && _visits.loading,
                skeleton: const HistorySkeleton(),
                child: body,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item});
  final _Item item;

  ({IconData icon, Color color}) _look(
    BuildContext context,
  ) => switch (item.kind) {
    _Kind.sos => (icon: Icons.sos_rounded, color: context.pal.redText),
    _Kind.visit => (icon: Icons.home_outlined, color: context.pal.orangeText),
    _Kind.checkup => (
      icon: Icons.favorite_border_rounded,
      color: AppColors.blue,
    ),
    _Kind.checkupUpdated => (icon: Icons.edit_outlined, color: AppColors.blue),
  };

  @override
  Widget build(BuildContext context) {
    final visit = item.visit;
    final page = item.page;
    final look = _look(context);
    final opens = visit != null || page != null;

    return InkWell(
      onTap: !opens
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => visit != null
                    ? VisitDetailsScreen(record: visit)
                    : page!(ctx),
              ),
            ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.lg, 14, Sp.md, 14),
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
                  Row(
                    children: [
                      // New and not opened yet: a dot and a bolder title, so it does not
                      // depend on colour.
                      if (item.unseen)
                        Semantics(
                          label: 'New update',
                          child: Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: Sp.sm),
                            decoration: BoxDecoration(
                              color: AppColors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          item.title,
                          style: item.unseen
                              ? T.rowTitle.copyWith(fontWeight: FontWeight.w800)
                              : T.rowTitle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: T.secondary.muted(context),
                  ),
                  if (item.status != null) ...[
                    const SizedBox(height: Sp.xs),
                    Text(
                      item.status!,
                      style: T.label.copyWith(
                        color: item.statusColor ?? context.pal.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Sp.sm),
            Text(formatTime(item.time), style: T.meta.muted(context)),
            if (opens)
              Padding(
                padding: EdgeInsets.only(left: 2),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: context.pal.muted,
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
  Widget build(BuildContext context) => EmptyState(
    title: 'Nothing here yet',
    message: switch (filter) {
      _Filter.checkups => 'Check-ups a GoBiker records for you will show here.',
      _Filter.visits => 'Home visits you request will show here.',
      _Filter.sos => 'SOS requests you send will show here.',
      _Filter.all => 'Check-ups, home visits and SOS requests will show here.',
    },
  );
}
