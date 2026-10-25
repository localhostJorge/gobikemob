import 'package:flutter/material.dart';

import '../../core/appointments.dart';
import '../../core/auth_service.dart';
import 'app_colors.dart';
import 'emergency_request_screen.dart' show kLocations;
import 'skeletons.dart';
import 'ui_kit.dart';
import 'visit_record.dart' show formatDate;

({IconData icon, Color color, String help}) _statusStyle(
  Appointment a,
) => switch (a.status) {
  'accepted' => (
    icon: Icons.directions_bike_rounded,
    color: AppColors.blue,
    help:
        '${a.gobikerName ?? 'A GoBiker'} will visit you. They may call you first.',
  ),
  'completed' => (
    icon: Icons.check_circle_rounded,
    color: AppColors.greenText,
    help: 'Your visit is done. The check-up is in your Medical History.',
  ),
  'declined' => (
    icon: Icons.block_rounded,
    color: AppColors.textMuted,
    help: a.declineNote ?? 'The admin could not schedule this visit.',
  ),
  'cancelled' => (
    icon: Icons.cancel_outlined,
    color: AppColors.textMuted,
    help: 'You cancelled this request.',
  ),
  _ => (
    icon: Icons.schedule_rounded,
    color: AppColors.orangeText,
    help: 'Waiting for a GoBiker in your barangay to accept it.',
  ),
};

/// The resident asks for a GoBiker to visit their home for a check-up,
/// and follows the request.
class AppointmentScreen extends StatefulWidget {
  const AppointmentScreen({super.key});

  @override
  State<AppointmentScreen> createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends State<AppointmentScreen> {
  final _store = ResidentAppointments.instance;
  final _formKey = GlobalKey<_RequestFormState>();
  final _sending = ValueNotifier<bool>(false);
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _store.load();
  }

  @override
  void dispose() {
    _sending.dispose();
    super.dispose();
  }

  Future<void> _cancel(Appointment a) async {
    final ok = await showConfirm(
      context,
      title: 'Cancel this visit?',
      message: a.gobikerName == null
          ? 'Your request will be withdrawn.'
          : '${a.gobikerName} will be told not to come.',
      confirmLabel: 'Cancel visit',
      cancelLabel: 'Keep it',
      destructive: true,
    );
    if (!ok || !mounted) return;

    setState(() => _cancelling = true);
    final error = await _store.cancel(a.id);
    if (!mounted) return;
    setState(() => _cancelling = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(error ?? 'Visit request cancelled.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: patientAppBar(context, 'Home visit'),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            final firstLoad = !_store.loaded;
            if (firstLoad && !_store.loading && _store.error != null) {
              return ErrorState(message: _store.error!, onRetry: _store.load);
            }

            final current = _store.current;
            final past = _store.appointments.where((a) => !a.isOpen).toList();

            return LoadSwitcher(
              loading: firstLoad && _store.loading,
              skeleton: const Padding(
                padding: EdgeInsets.fromLTRB(
                  Sp.gutter,
                  Sp.sm,
                  Sp.gutter,
                  Sp.xl,
                ),
                child: VisitCardSkeleton(),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      color: AppColors.red,
                      onRefresh: _store.load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          Sp.gutter,
                          Sp.sm,
                          Sp.gutter,
                          Sp.xl,
                        ),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        children: [
                          if (current != null)
                            _StatusCard(
                              appointment: current,
                              cancelling: _cancelling,
                              onCancel: () => _cancel(current),
                            )
                          else
                            _RequestForm(key: _formKey, sending: _sending),
                          if (past.isNotEmpty) ...[
                            const SizedBox(height: Sp.xl),
                            const SectionHeader('Past requests'),
                            CardGroup(
                              dividerIndent: 52,
                              children: [
                                for (final a in past) _PastRow(appointment: a),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // The one main action, always in the same spot.
                  if (current == null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Sp.gutter,
                        Sp.xs,
                        Sp.gutter,
                        Sp.lg,
                      ),
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _sending,
                        builder: (context, sending, _) => PrimaryButton(
                          label: 'Request visit',
                          loading: sending,
                          onPressed: () => _formKey.currentState?.submit(),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.appointment,
    required this.cancelling,
    required this.onCancel,
  });
  final Appointment appointment;
  final bool cancelling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final s = _statusStyle(a);
    return Semantics(
      container: true,
      liveRegion: true,
      child: AppCard(
        borderColor: s.color.withValues(alpha: 0.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(s.icon, color: s.color, size: 22),
                const SizedBox(width: Sp.sm),
                Expanded(
                  child: Text(
                    a.statusLabel,
                    style: T.heading.copyWith(color: s.color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Sp.sm),
            Text(s.help, style: T.body),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: Sp.lg),
              child: Divider(height: 1, color: AppColors.divider),
            ),
            _FactRow(
              Icons.event_rounded,
              '${formatDate(a.preferredDate)} · ${a.windowLabel}',
            ),
            _FactRow(Icons.home_outlined, '${a.address}, ${a.barangay}'),
            _FactRow(Icons.notes_rounded, a.reason),
            const SizedBox(height: Sp.lg),
            SecondaryButton(
              label: 'Cancel visit',
              destructive: true,
              loading: cancelling,
              onPressed: onCancel,
            ),
          ],
        ),
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Sp.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: Sp.md),
        Expanded(child: Text(text, style: T.body)),
      ],
    ),
  );
}

class _PastRow extends StatelessWidget {
  const _PastRow({required this.appointment});
  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final s = _statusStyle(a);
    return NavRow(
      icon: s.icon,
      color: s.color,
      title: '${a.statusLabel} · ${formatDate(a.preferredDate)}',
      subtitle: a.status == 'declined' ? s.help : a.reason,
    );
  }
}

class _RequestForm extends StatefulWidget {
  const _RequestForm({super.key, required this.sending});

  /// The screen's button shows this while the request is being sent.
  final ValueNotifier<bool> sending;

  @override
  State<_RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends State<_RequestForm> {
  final _form = GlobalKey<FormState>();
  final _address = TextEditingController();
  final _reason = TextEditingController();
  late String? _barangay = _homeBarangay();
  DateTime? _date;
  bool _dateMissing = false;
  String _window = 'morning';

  static List<String> get _barangays => kLocations['Bugallon'] ?? const [];

  static String? _homeBarangay() {
    final home = AuthService.instance.currentUser?.barangay;
    return _barangays.contains(home) ? home : null;
  }

  @override
  void dispose() {
    _address.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today.add(const Duration(days: 1)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 30)),
      helpText: 'Preferred visit date',
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _dateMissing = false;
      });
    }
  }

  /// Called by the screen's "Request visit" button.
  Future<void> submit() async {
    final valid = _form.currentState!.validate();
    setState(() => _dateMissing = _date == null);
    if (!valid || _date == null) return;

    widget.sending.value = true;
    final error = await ResidentAppointments.instance.request(
      barangay: _barangay!,
      address: _address.text,
      date: _date!,
      window: _window,
      reason: _reason.text,
    );
    widget.sending.value = false;
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            error ?? 'Visit requested. A GoBiker in your barangay will accept it soon.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Request a home check-up', style: T.title),
          const SizedBox(height: Sp.sm),
          const Text(
            'A GoBiker in your barangay will visit to check your blood '
            'pressure, pulse, temperature and more. For emergencies, use the '
            'SOS button instead.',
            style: T.secondary,
          ),
          const SizedBox(height: Sp.xl),
          DropdownButtonFormField<String>(
            initialValue: _barangay,
            isExpanded: true,
            decoration: inputDecoration('Barangay', Icons.map_outlined),
            items: [
              for (final b in _barangays)
                DropdownMenuItem(value: b, child: Text(b)),
            ],
            onChanged: (v) => setState(() => _barangay = v),
            validator: (v) => v == null ? 'Select your barangay' : null,
          ),
          const SizedBox(height: Sp.lg),
          TextFormField(
            controller: _address,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 255,
            decoration: inputDecoration(
              'House address or landmark',
              Icons.home_outlined,
            ).copyWith(counterText: ''),
            validator: (v) => (v == null || v.trim().length < 3)
                ? 'Tell the GoBiker where to find you'
                : null,
          ),
          const SizedBox(height: Sp.lg),
          _DateField(date: _date, onTap: _pickDate, showError: _dateMissing),
          const SizedBox(height: Sp.lg),
          const Text('Time of day', style: T.label),
          const SizedBox(height: Sp.sm),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: 'morning',
                label: Text('Morning'),
                icon: Icon(Icons.wb_sunny_outlined),
              ),
              ButtonSegment(
                value: 'afternoon',
                label: Text('Afternoon'),
                icon: Icon(Icons.wb_twilight_rounded),
              ),
            ],
            selected: {_window},
            onSelectionChanged: (s) => setState(() => _window = s.first),
            style: SegmentedButton.styleFrom(
              minimumSize: const Size(0, 48),
              textStyle: T.label.copyWith(fontFamily: kFontFamily),
              side: const BorderSide(color: AppColors.line),
              selectedBackgroundColor: AppColors.textDark,
              selectedForegroundColor: Colors.white,
              foregroundColor: AppColors.textDark,
            ),
          ),
          const SizedBox(height: Sp.lg),
          TextFormField(
            controller: _reason,
            minLines: 3,
            maxLines: 5,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: inputDecoration(
              'Reason for the visit',
              Icons.notes_rounded,
            ).copyWith(hintText: 'e.g. Blood pressure check for my mother'),
            validator: (v) => (v == null || v.trim().length < 3)
                ? 'Tell the GoBiker why you need a visit'
                : null,
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.date,
    required this.onTap,
    required this.showError,
  });
  final DateTime? date;
  final VoidCallback onTap;
  final bool showError;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: date == null
        ? 'Choose a preferred visit date'
        : 'Preferred visit date, ${formatDate(date!)}. Tap to change.',
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Rd.control),
      child: InputDecorator(
        decoration: inputDecoration(
          'Preferred date',
          Icons.event_rounded,
        ).copyWith(errorText: showError ? 'Choose a date' : null),
        child: Text(
          date == null ? 'Choose a date' : formatDate(date!),
          style: date == null
              ? T.body.copyWith(color: AppColors.textMuted)
              : T.body,
        ),
      ),
    ),
  );
}
