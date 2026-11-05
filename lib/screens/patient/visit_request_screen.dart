import 'package:flutter/material.dart';

import '../../core/appointments.dart';
import 'app_colors.dart';
import 'gobiker_picker.dart';
import 'patient_store.dart';
import 'ui_kit.dart';
import 'visit_record.dart' show formatDate;
import 'visit_request_card.dart';

/// One home-visit request: how it stands, what was asked, the GoBiker's message when they
/// declined, a way to cancel it while it is open, and, after a decline, other GoBikers to ask
/// instead.
///
/// Opened from History, from the Home screen's "visit declined" row, and from the phone
/// notification about the request. Opening it marks the answer as seen.
class VisitRequestScreen extends StatefulWidget {
  const VisitRequestScreen({
    super.key,
    required this.appointmentId,
    this.loader,
  });

  final int appointmentId;

  /// Replaces the lookup of GoBikers. Only tests set this.
  final GobikerLoader? loader;

  @override
  State<VisitRequestScreen> createState() => _VisitRequestScreenState();
}

class _VisitRequestScreenState extends State<VisitRequestScreen> {
  final _store = ResidentAppointments.instance;
  bool _cancelling = false;
  bool _sending = false;

  Appointment? get _appointment => _store.appointments
      .where((a) => a.id == widget.appointmentId)
      .firstOrNull;

  @override
  void initState() {
    super.initState();
    _store.addListener(_markSeen);
    // After the first frame: loading tells the screens below this one to rebuild, which they
    // must not be told while this one is still being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _store.load(); // the answer may have changed since the list was loaded
      _markSeen();
    });
  }

  @override
  void dispose() {
    _store.removeListener(_markSeen);
    super.dispose();
  }

  /// They are looking at it, so the answer is no longer new (also when it changes while open).
  void _markSeen() {
    final a = _appointment;
    if (a != null) PatientStore.instance.markVisitSeen(a);
  }

  Future<void> _cancel(Appointment a) async {
    setState(() => _cancelling = true);
    await cancelVisitRequest(context, a);
    if (mounted) setState(() => _cancelling = false);
  }

  /// Sends the same request again, this time to [gobiker].
  Future<void> _askAgain(Appointment a, GobikerOption gobiker) async {
    var date = a.preferredDate;
    final today = DateUtils.dateOnly(DateTime.now());
    // The old date has passed: they pick a new one first.
    if (date.isBefore(today)) {
      final picked = await showDatePicker(
        context: context,
        initialDate: today.add(const Duration(days: 1)),
        firstDate: today,
        lastDate: today.add(const Duration(days: 30)),
        helpText: 'New visit date',
      );
      if (picked == null || !mounted) return;
      date = picked;
    }

    final ok = await showConfirm(
      context,
      title: 'Ask ${gobiker.name}?',
      message:
          '${formatDate(date)} · ${a.windowLabel}\n${a.address}, ${a.barangay}\n\n'
          '${gobiker.name} will accept or decline it in their app.',
      confirmLabel: 'Send request',
      cancelLabel: 'Not now',
    );
    if (!ok || !mounted) return;

    setState(() => _sending = true);
    final error = await _store.request(
      barangay: a.barangay,
      address: a.address,
      date: date,
      window: a.window,
      reason: a.reason,
      gobikerId: gobiker.id,
    );
    if (!mounted) return;
    setState(() => _sending = false);

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            error ??
                'Visit requested. ${gobiker.name} will accept or decline it soon.',
          ),
        ),
      );
    if (error == null) {
      // Followed up: the declined row no longer needs to wait on the Home screen.
      await PatientStore.instance.hideDecline(a.id);
      if (mounted) Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pal.background,
      appBar: patientAppBar(context, 'Visit request'),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([_store, PatientStore.instance]),
          builder: (context, _) {
            final a = _appointment;
            if (a == null) {
              if (!_store.loaded) {
                return const Center(child: CircularProgressIndicator());
              }
              return const EmptyState(
                title: 'This request is no longer here',
                message:
                    'It may have been cleared from your history. '
                    'You can ask for a new visit from the Home screen.',
              );
            }

            return AbsorbPointer(
              absorbing: _sending,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Sp.gutter,
                  Sp.sm,
                  Sp.gutter,
                  Sp.xl,
                ),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  VisitRequestCard(
                    appointment: a,
                    cancelling: _cancelling,
                    onCancel: a.isOpen ? () => _cancel(a) : null,
                  ),
                  if (a.status == 'declined') ..._suggestions(a),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Other GoBikers to ask: the request's own barangay first, the barangay changeable.
  List<Widget> _suggestions(Appointment a) {
    final hidden = PatientStore.instance.isDeclineHidden(a.id);
    return [
      const SizedBox(height: Sp.xl),
      const SectionHeader('Ask someone else'),
      Text(
        'Suggested GoBikers in ${a.barangay}. Choose one to send the same '
        'request, or look in another barangay.',
        style: T.secondary.muted(context),
      ),
      const SizedBox(height: Sp.lg),
      GobikerPickerBody(
        startBarangay: a.barangay,
        scrollable: false,
        loader: widget.loader,
        // Not the one who just said no, and not anyone who already has a request open.
        excludeIds: {?a.gobikerId},
        disabledIds: _store.openGobikerIds,
        onPick: (g) => _askAgain(a, g),
      ),
      if (_sending)
        const Padding(
          padding: EdgeInsets.only(top: Sp.lg),
          child: Center(child: CircularProgressIndicator()),
        ),
      if (!hidden) ...[
        const SizedBox(height: Sp.xl),
        QuietButton(
          label: 'Hide this from the Home screen',
          icon: Icons.visibility_off_outlined,
          onPressed: () => PatientStore.instance.hideDecline(a.id),
        ),
      ],
    ];
  }
}
