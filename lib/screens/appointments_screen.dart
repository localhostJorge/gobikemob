import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/appointments.dart';
import '../core/patient_service.dart';
import '../core/theme.dart';
import '../widgets/app_toast.dart';

/// Home-visit requests for the GoBiker: the ones residents sent them (to
/// accept or decline), and the visits they took (to call and mark done).
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final _store = GobikerAppointments.instance;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _store.load();
  }

  Future<void> _accept(Appointment a) async {
    setState(() => _busy.add(a.id));
    final error = await _store.accept(a.id);
    if (!mounted) return;
    setState(() => _busy.remove(a.id));
    AppToast.show(
      context,
      error ??
          'Visit accepted. ${a.residentName ?? 'The resident'} can see you are coming.',
      type: error == null ? ToastType.success : ToastType.error,
    );
  }

  Future<void> _decline(Appointment a) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _DeclineDialog(residentName: a.residentName),
    );
    if (note == null || !mounted) return;

    setState(() => _busy.add(a.id));
    final error = await _store.decline(a.id, note: note);
    if (!mounted) return;
    setState(() => _busy.remove(a.id));
    AppToast.show(
      context,
      error ??
          'Request declined. ${a.residentName ?? 'The resident'} can ask another GoBiker.',
      type: error == null ? ToastType.success : ToastType.error,
    );
  }

  Future<void> _complete(Appointment a) async {
    final choice = await showModalBottomSheet<_DoneChoice>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CompleteSheet(appointment: a),
    );
    if (choice == null || !mounted) return;

    setState(() => _busy.add(a.id));
    final error = await _store.complete(a.id, patientId: choice.patientId);
    if (!mounted) return;
    setState(() => _busy.remove(a.id));
    AppToast.show(
      context,
      error ?? 'Visit marked as done.',
      type: error == null ? ToastType.success : ToastType.error,
    );
  }

  Future<void> _call(String number) async {
    final ok = await launchUrl(Uri(scheme: 'tel', path: number));
    if (!ok && mounted) {
      AppToast.show(
        context,
        "Couldn't open the dialer.",
        type: ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final toVisit = _store.mine.where((a) => a.status == 'accepted').length;
        final toAnswer = _store.requests.length + _store.available.length;
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              scrolledUnderElevation: 0,
              centerTitle: true,
              title: const Text(
                'Appointments',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              bottom: TabBar(
                labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                tabs: [
                  Tab(text: 'Requests ($toAnswer)'),
                  Tab(text: 'My visits ($toVisit)'),
                ],
              ),
            ),
            body: SafeArea(
              child: TabBarView(
                children: [
                  _list(
                    _store.requests,
                    // Older app versions send requests to the whole barangay.
                    more: _store.available,
                    moreTitle: 'Open requests in your barangay',
                    empty: 'No requests for you.',
                    emptyHint: 'When a resident chooses you for a home check-up, it shows up here.',
                  ),
                  _list(
                    _store.mine,
                    empty: 'No visits yet.',
                    emptyHint: 'Requests you accept appear here.',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _card(Appointment a) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: _AppointmentCard(
      appointment: a,
      busy: _busy.contains(a.id),
      onAccept: a.status == 'pending' ? () => _accept(a) : null,
      // Only a request the resident sent to this GoBiker can be declined.
      onDecline: a.status == 'pending' && a.gobikerId != null
          ? () => _decline(a)
          : null,
      onComplete: a.status == 'accepted' ? () => _complete(a) : null,
      onCall: a.residentMobile == null ? null : () => _call(a.residentMobile!),
    ),
  );

  Widget _list(
    List<Appointment> items, {
    List<Appointment> more = const [],
    String? moreTitle,
    required String empty,
    required String emptyHint,
  }) {
    final muted = Theme.of(context).colorScheme.onSurface
        .withValues(alpha: 0.6);

    if (!_store.loaded && _store.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _store.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_store.error != null)
            _ErrorBanner(message: _store.error!, onRetry: _store.load),
          if (items.isEmpty && more.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 64),
              child: Column(
                children: [
                  Icon(Icons.event_available_rounded, size: 56, color: muted),
                  const SizedBox(height: 14),
                  Text(
                    empty,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    emptyHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: muted),
                  ),
                ],
              ),
            )
          else ...[
            for (final a in items) _card(a),
            if (more.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.only(
                  top: items.isEmpty ? 0 : 12,
                  bottom: 8,
                ),
                child: Text(
                  moreTitle ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (final a in more) _card(a),
            ],
          ],
        ],
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.busy,
    this.onAccept,
    this.onDecline,
    this.onComplete,
    this.onCall,
  });

  final Appointment appointment;
  final bool busy;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onComplete;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final done = a.status == 'completed';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  a.residentName ?? 'Resident',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (done)
                const _Chip(
                  label: 'Done',
                  icon: Icons.check_circle_rounded,
                  color: AppTheme.successGreen,
                ),
            ],
          ),
          const SizedBox(height: 8),
          _line(
            Icons.event_rounded,
            '${DateFormat('EEE, MMM d').format(a.preferredDate)} · '
            '${a.window == 'afternoon' ? 'Afternoon' : 'Morning'}',
            muted,
          ),
          _line(Icons.home_outlined, '${a.address}, ${a.barangay}', muted),
          _line(Icons.notes_rounded, a.reason, muted),
          if (!done) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onCall != null)
                  OutlinedButton.icon(
                    onPressed: onCall,
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: Text(a.residentMobile ?? 'Call'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                if (onAccept != null)
                  FilledButton.icon(
                    onPressed: busy ? null : onAccept,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(busy ? 'Saving…' : 'Accept'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      backgroundColor: AppTheme.blue,
                    ),
                  ),
                if (onDecline != null)
                  OutlinedButton.icon(
                    onPressed: busy ? null : onDecline,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Decline'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: AppTheme.errorRed,
                    ),
                  ),
                if (onComplete != null)
                  FilledButton.icon(
                    onPressed: busy ? null : onComplete,
                    icon: const Icon(Icons.task_alt_rounded, size: 18),
                    label: Text(busy ? 'Saving…' : 'Mark visit done'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      backgroundColor: AppTheme.successGreen,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(IconData icon, String text, Color muted) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: muted),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5))),
      ],
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.icon, required this.color});
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 18,
            color: AppTheme.errorRed,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

/// Asks for an optional reason before declining; returns it ('' for none),
/// or null when the GoBiker changes their mind.
class _DeclineDialog extends StatefulWidget {
  const _DeclineDialog({this.residentName});
  final String? residentName;

  @override
  State<_DeclineDialog> createState() => _DeclineDialogState();
}

class _DeclineDialogState extends State<_DeclineDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Decline this visit?'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${widget.residentName ?? 'The resident'} will be told, and can ask '
          'another GoBiker.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          maxLength: 300,
          maxLines: 3,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'e.g. I am out of town that day',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        child: const Text('Keep it'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _note.text.trim()),
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: AppTheme.errorRed,
        ),
        child: const Text('Decline'),
      ),
    ],
  );
}

/// What "Mark visit done" saves: optionally the check-up recorded there.
class _DoneChoice {
  const _DoneChoice(this.patientId);
  final int? patientId;
}

/// Lets the GoBiker link the check-up they just recorded at this visit.
class _CompleteSheet extends StatefulWidget {
  const _CompleteSheet({required this.appointment});
  final Appointment appointment;

  @override
  State<_CompleteSheet> createState() => _CompleteSheetState();
}

class _CompleteSheetState extends State<_CompleteSheet> {
  List<Map<String, dynamic>>? _recent;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await PatientService.instance.list();
    if (!mounted) return;
    final since = DateTime.now().subtract(const Duration(days: 2));
    setState(() {
      _error = res.error;
      // Check-ups from the last two days, newest first (the list is sorted).
      _recent = (res.data ?? const [])
          .where((p) {
            final at = DateTime.tryParse('${p['recorded_at'] ?? ''}');
            return at != null && at.isAfter(since);
          })
          .take(10)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface
        .withValues(alpha: 0.6);
    final recent = _recent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Mark visit done',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Which check-up did you record for '
            '${widget.appointment.residentName ?? 'this resident'}?',
            style: TextStyle(fontSize: 13, color: muted),
          ),
          const SizedBox(height: 12),
          if (recent == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppTheme.errorRed)),
            if (recent.isEmpty && _error == null)
              Text(
                'No check-ups recorded in the last 2 days.',
                style: TextStyle(fontSize: 13, color: muted),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in recent)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.monitor_heart_outlined),
                      title: Text('${p['name']}'),
                      subtitle: Text(
                        '${p['date']} · ${p['time']} · BP ${p['sys']}/${p['dia']}',
                      ),
                      onTap: () => Navigator.pop(
                        context,
                        _DoneChoice(int.tryParse('${p['id']}')),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, const _DoneChoice(null)),
            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            child: const Text('Done without a check-up'),
          ),
        ],
      ),
    );
  }
}
