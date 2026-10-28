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
    help:
        a.declineNote ??
        'This visit could not be scheduled. You can ask another GoBiker.',
  ),
  'cancelled' => (
    icon: Icons.cancel_outlined,
    color: AppColors.textMuted,
    help: 'You cancelled this request.',
  ),
  _ => (
    icon: Icons.schedule_rounded,
    color: AppColors.orangeText,
    help: a.gobikerName == null
        ? 'Waiting for a GoBiker in your barangay to accept it.'
        : 'Waiting for ${a.gobikerName} to accept. You will get a notification.',
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
            if (a.gobikerName != null)
              _FactRow(
                Icons.directions_bike_rounded,
                a.gobikerBarangay == null
                    ? a.gobikerName!
                    : '${a.gobikerName} · ${a.gobikerBarangay}',
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
  GobikerOption? _gobiker;
  bool _gobikerMissing = false;
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

  Future<void> _pickGobiker() async {
    final picked = await showModalBottomSheet<GobikerOption>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Rd.sheet)),
      ),
      builder: (_) => _GobikerSheet(
        // Start with the GoBikers where the visit is; others are one tap away.
        startBarangay: _barangay ?? _homeBarangay(),
        selectedId: _gobiker?.id,
      ),
    );
    if (picked != null) {
      setState(() {
        _gobiker = picked;
        _gobikerMissing = false;
      });
    }
  }

  /// Called by the screen's "Request visit" button.
  Future<void> submit() async {
    final valid = _form.currentState!.validate();
    setState(() {
      _dateMissing = _date == null;
      _gobikerMissing = _gobiker == null;
    });
    if (!valid || _date == null || _gobiker == null) return;

    widget.sending.value = true;
    final error = await ResidentAppointments.instance.request(
      barangay: _barangay!,
      address: _address.text,
      date: _date!,
      window: _window,
      reason: _reason.text,
      gobikerId: _gobiker!.id,
    );
    widget.sending.value = false;
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            error ??
                'Visit requested. ${_gobiker!.name} will accept or decline it soon.',
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
            'Choose a GoBiker to visit you and check your blood pressure, '
            'pulse, temperature and more. They accept or decline in their '
            'app. For emergencies, use the SOS button instead.',
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
          _GobikerField(
            gobiker: _gobiker,
            onTap: _pickGobiker,
            showError: _gobikerMissing,
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

/// Looks like the other fields; opens the GoBiker list.
class _GobikerField extends StatelessWidget {
  const _GobikerField({
    required this.gobiker,
    required this.onTap,
    required this.showError,
  });
  final GobikerOption? gobiker;
  final VoidCallback onTap;
  final bool showError;

  @override
  Widget build(BuildContext context) {
    final g = gobiker;
    return Semantics(
      button: true,
      label: g == null
          ? 'Choose a GoBiker'
          : 'GoBiker, ${g.name} from ${g.barangay}. Tap to change.',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Rd.control),
        child: InputDecorator(
          decoration: inputDecoration(
            'GoBiker',
            Icons.directions_bike_rounded,
            suffix: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textMuted,
            ),
          ).copyWith(errorText: showError ? 'Choose a GoBiker' : null),
          child: Text(
            g == null ? 'Choose a GoBiker' : '${g.name} · ${g.barangay}',
            style: g == null
                ? T.body.copyWith(color: AppColors.textMuted)
                : T.body,
          ),
        ),
      ),
    );
  }
}

/// The GoBikers of a barangay (the visit's barangay first), with a switch to
/// look at another barangay. Returns the chosen one.
class _GobikerSheet extends StatefulWidget {
  const _GobikerSheet({required this.startBarangay, this.selectedId});
  final String? startBarangay;
  final int? selectedId;

  @override
  State<_GobikerSheet> createState() => _GobikerSheetState();
}

class _GobikerSheetState extends State<_GobikerSheet> {
  late String? _barangay = widget.startBarangay;
  List<GobikerOption> _list = const [];
  bool _loading = true;
  String? _error;

  String? get _home => AuthService.instance.currentUser?.barangay;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final barangay = _barangay;
    final res = await ResidentAppointments.instance.gobikers(barangay);
    // A slower answer for a barangay the resident already moved away from.
    if (!mounted || barangay != _barangay) return;
    setState(() {
      _list = res.gobikers;
      _error = res.error;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.gutter, Sp.lg, Sp.gutter, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Choose a GoBiker', style: T.heading),
                const SizedBox(height: Sp.xs),
                const Text(
                  'GoBikers from your barangay are shown first. You can also '
                  'choose one from another barangay.',
                  style: T.secondary,
                ),
                const SizedBox(height: Sp.lg),
                DropdownButtonFormField<String>(
                  initialValue: _barangay,
                  isExpanded: true,
                  decoration: inputDecoration(
                    'GoBikers from',
                    Icons.map_outlined,
                  ),
                  items: [
                    for (final b in _RequestFormState._barangays)
                      DropdownMenuItem(
                        value: b,
                        child: Text(b == _home ? '$b (your barangay)' : b),
                      ),
                  ],
                  onChanged: (v) {
                    if (v == null || v == _barangay) return;
                    setState(() => _barangay = v);
                    _load();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: Sp.md),
          Flexible(child: _body()),
          SizedBox(height: Sp.md + media.padding.bottom),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(Sp.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return EmptyState(
        title: "Couldn't load the GoBikers",
        message: _error!,
        actionLabel: 'Try again',
        onAction: _load,
      );
    }
    if (_list.isEmpty) {
      return EmptyState(
        title: 'No GoBikers in ${_barangay ?? 'your barangay'} yet',
        message: 'Choose another barangay above to see its GoBikers.',
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: Sp.sm),
      itemCount: _list.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, indent: 72, color: AppColors.divider),
      itemBuilder: (context, i) {
        final g = _list[i];
        final selected = g.id == widget.selectedId;
        return ListTile(
          minVerticalPadding: 12,
          leading: CircleAvatar(
            backgroundColor: AppColors.background,
            foregroundColor: AppColors.textDark,
            child: Text(g.name.isEmpty ? '?' : g.name[0].toUpperCase()),
          ),
          title: Text(
            g.name,
            style: selected
                ? T.rowTitle.copyWith(fontWeight: FontWeight.w700)
                : T.rowTitle,
          ),
          subtitle: Text(
            '${g.barangay} · ${g.visitsDone == 1 ? '1 visit done' : '${g.visitsDone} visits done'}',
            style: T.secondary,
          ),
          trailing: selected
              ? const Icon(Icons.check_rounded, color: AppColors.textDark)
              : null,
          onTap: () => Navigator.pop(context, g),
        );
      },
    );
  }
}
