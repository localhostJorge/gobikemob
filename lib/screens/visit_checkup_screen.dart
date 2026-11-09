import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/appointments.dart';
import '../core/patient_service.dart';
import '../core/theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/confirm_modal.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/patient_form.dart';
import '../widgets/visit_note_dialog.dart';
import 'global_state.dart';

/// How the Home check-up screen was left, for the screen that opened it to say so.
enum VisitOutcome { recorded, withdrawn }

/// The check-up at an accepted home visit. Who the person is (name, address, contact, age)
/// comes from their request and account, so the GoBiker only enters what they measure, and
/// saving the check-up finishes the visit.
class VisitCheckupScreen extends StatefulWidget {
  const VisitCheckupScreen({super.key, required this.appointment});

  final Appointment appointment;

  @override
  State<VisitCheckupScreen> createState() => _VisitCheckupScreenState();
}

class _VisitCheckupScreenState extends State<VisitCheckupScreen> {
  final _formKey = GlobalKey<FormState>();
  final PatientFormControllers _c = PatientFormControllers();
  String? _busy; // what is being saved, while something is

  Appointment get _visit => widget.appointment;

  /// The resident gave no birthdate, so the GoBiker is asked how old they are.
  bool get _asksAge => _visit.residentAge == null;

  String get _who => _visit.residentName ?? 'the resident';

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _call() async {
    final number = _visit.residentMobile;
    if (number == null) return;
    final ok = await launchUrl(Uri(scheme: 'tel', path: number));
    if (!ok && mounted) {
      AppToast.show(
        context,
        "Couldn't open the dialer.",
        type: ToastType.error,
      );
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      AppToast.show(
        context,
        'Please check the highlighted fields.',
        type: ToastType.error,
      );
      return;
    }

    final confirmed = await ConfirmModal.show(
      context: context,
      icon: Icons.task_alt_rounded,
      color: AppTheme.successGreen,
      title: 'Save this check-up?',
      description:
          'It is saved for $_who, and this visit is marked done. '
          'They can read the results in their app.',
      confirmText: 'Save',
      onConfirm: () {},
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = 'Saving check-up...');
    final result = await PatientService.instance.recordVisitCheckup(
      _visit.id,
      _c.toMap(),
      age: _asksAge ? int.tryParse(_c.age.text.trim()) : null,
    );
    if (!mounted) return;

    if (!result.ok) {
      setState(() => _busy = null);
      AppToast.show(context, result.error!, type: ToastType.error);
      return; // stay on the form so nothing typed is lost
    }

    final saved = result.data!;
    if (!globalPatients.any((p) => p['id'] == saved['id'])) {
      globalPatients.insert(0, saved);
    }
    await GobikerAppointments.instance
        .load(); // the visit is done: off My visits
    if (!mounted) return;
    Navigator.pop(context, VisitOutcome.recorded);
  }

  Future<void> _withdraw() async {
    final note = await showVisitNoteDialog(
      context,
      title: "Can't do this visit?",
      message:
          '$_who will be told you can no longer make it, and can ask another '
          'GoBiker. No check-up is saved.',
      confirmLabel: "Can't do it",
      keepLabel: 'Back',
    );
    if (note == null || !mounted) return;

    setState(() => _busy = 'Telling the resident...');
    final error = await GobikerAppointments.instance.decline(
      _visit.id,
      note: note,
    );
    if (!mounted) return;
    setState(() => _busy = null);

    if (error != null) {
      AppToast.show(context, error, type: ToastType.error);
      return;
    }
    Navigator.pop(context, VisitOutcome.withdrawn);
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface
        .withValues(alpha: 0.6);

    return LoadingOverlay(
      isLoading: _busy != null,
      message: _busy,
      child: Scaffold(
        backgroundColor: authBackground(context),
        appBar: AppBar(
          backgroundColor: authBackground(context),
          scrolledUnderElevation: 0,
          centerTitle: true,
          title: const Text(
            'Home check-up',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ResidentCard(visit: _visit, onCall: _call),
                    const SizedBox(height: 28),
                    PatientForm(
                      controllers: _c,
                      personalDetails: false,
                      askAge: _asksAge,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _busy != null ? null : _save,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: const Text(
                        'Save check-up',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy != null ? null : _withdraw,
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: muted,
                      ),
                      child: const Text("Couldn't do this visit"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Who is being visited, taken from their request and account: nothing here is typed.
class _ResidentCard extends StatelessWidget {
  const _ResidentCard({required this.visit, required this.onCall});

  final Appointment visit;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final name = visit.residentName ?? 'Resident';
    final age = visit.residentAge;

    Widget line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: muted),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );

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
              InitialsAvatar(name, radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (age != null)
                      Text(
                        'Age $age',
                        style: TextStyle(fontSize: 13, color: muted),
                      ),
                  ],
                ),
              ),
            ],
          ),
          line(Icons.home_outlined, '${visit.address}, ${visit.barangay}'),
          line(
            Icons.event_rounded,
            '${DateFormat('EEE, MMM d').format(visit.preferredDate)} · '
            '${visit.window == 'afternoon' ? 'Afternoon' : 'Morning'}',
          ),
          if (visit.residentMobile != null)
            line(Icons.phone_outlined, visit.residentMobile!),
          line(Icons.notes_rounded, visit.reason),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 16,
                color: AppTheme.successGreen,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Filled in from their request. Only the check-up is left.',
                  style: TextStyle(fontSize: 12.5, color: muted),
                ),
              ),
            ],
          ),
          if (visit.residentMobile != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onCall,
              icon: const Icon(Icons.call_rounded, size: 18),
              label: const Text('Call'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
