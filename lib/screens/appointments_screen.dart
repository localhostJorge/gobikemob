import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/appointments.dart';
import '../core/theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/visit_note_dialog.dart';
import 'visit_checkup_screen.dart';

/// Home-visit requests for the GoBiker: the ones residents sent them (to
/// accept or decline), and the visits they took, where the check-up is recorded.
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen>
    with SingleTickerProviderStateMixin {
  final _store = GobikerAppointments.instance;
  final Set<int> _busy = {};
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    _store.load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
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
    // It is in My visits now, ready for the check-up: take them there.
    if (error == null) _tabs.animateTo(1);
  }

  Future<void> _decline(Appointment a) async {
    final note = await showVisitNoteDialog(
      context,
      title: 'Decline this visit?',
      message:
          '${a.residentName ?? 'The resident'} will be told, and can ask '
          'another GoBiker.',
      confirmLabel: 'Decline',
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

  /// The check-up at an accepted visit: their details are filled in, saving it finishes the visit.
  Future<void> _openCheckup(Appointment a) async {
    final outcome = await Navigator.push<VisitOutcome>(
      context,
      MaterialPageRoute(builder: (_) => VisitCheckupScreen(appointment: a)),
    );
    if (outcome == null || !mounted) return;
    AppToast.show(
      context,
      outcome == VisitOutcome.recorded
          ? 'Check-up saved. Visit done.'
          : '${a.residentName ?? 'The resident'} was told you cannot make it.',
      type: ToastType.success,
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
        // Visits that are done are in History; this list is what is still to do.
        final toDo = _store.mine.where((a) => a.status == 'accepted').toList();
        final toAnswer = _store.requests.length + _store.available.length;
        return Scaffold(
          appBar: AppBar(
            scrolledUnderElevation: 0,
            centerTitle: true,
            title: const Text(
              'Appointments',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            bottom: TabBar(
              controller: _tabs,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700),
              tabs: [
                Tab(text: 'Requests ($toAnswer)'),
                Tab(text: 'My visits (${toDo.length})'),
              ],
            ),
          ),
          body: SafeArea(
            child: TabBarView(
              controller: _tabs,
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
                  toDo,
                  empty: 'No visits to do.',
                  emptyHint: 'Requests you accept appear here. Tap one to record the check-up.',
                ),
              ],
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
      onOpen: a.status == 'accepted' ? () => _openCheckup(a) : null,
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
    this.onOpen,
    this.onCall,
  });

  final Appointment appointment;
  final bool busy;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  /// An accepted visit: opens the check-up (the whole card, and its button).
  final VoidCallback? onOpen;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final radius = BorderRadius.circular(16);

    return Material(
      color: theme.cardColor,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onOpen,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: radius,
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
                  if (onOpen != null)
                    Icon(Icons.chevron_right_rounded, color: muted),
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
              const SizedBox(height: 10),
              if (onOpen != null)
                // An accepted visit: the number to call, and the check-up to its right. Nothing
                // here changes while the app works, so nothing moves.
                Row(
                  children: [
                    if (onCall != null) ...[
                      Flexible(child: _callButton()),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onOpen,
                        icon: const Icon(
                          Icons.monitor_heart_outlined,
                          size: 18,
                        ),
                        label: const Text(
                          'Record check-up',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          backgroundColor: AppTheme.successGreen,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (onCall != null) _callButton(),
                    if (onAccept != null)
                      FilledButton.icon(
                        onPressed: busy ? null : onAccept,
                        icon: _icon(Icons.check_rounded),
                        label: const Text('Accept'),
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
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The button's icon; a small spinner while saving, the same size so the button keeps its width.
  Widget _icon(IconData icon) => busy
      ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : Icon(icon, size: 18);

  Widget _callButton() => OutlinedButton.icon(
    onPressed: onCall,
    icon: const Icon(Icons.call_rounded, size: 18),
    label: Text(
      appointment.residentMobile ?? 'Call',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
  );

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
