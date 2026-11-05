import 'package:flutter/material.dart';

import '../../core/appointments.dart';
import '../../core/auth_service.dart';
import 'app_colors.dart';
import 'gobiker_picker.dart';
import 'ui_kit.dart';
import 'visit_record.dart' show formatDate;

/// The resident asks for a GoBiker to visit their home for a check-up.
///
/// It always opens the request form, even while another request is waiting: they can have up
/// to [ResidentAppointments.maxOpen] open at once, and see each one's answer in History.
class AppointmentScreen extends StatefulWidget {
  const AppointmentScreen({super.key});

  @override
  State<AppointmentScreen> createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends State<AppointmentScreen> {
  final _store = ResidentAppointments.instance;
  final _formKey = GlobalKey<_RequestFormState>();
  final _sending = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    // After the first frame, so the screens below are not told to rebuild mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _store.load(); // to know how many are open
    });
  }

  @override
  void dispose() {
    _sending.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pal.background,
      appBar: patientAppBar(context, 'Home visit'),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            final open = _store.open.length;
            final atLimit = open >= ResidentAppointments.maxOpen;

            return Column(
              children: [
                Expanded(
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
                      if (open > 0) ...[
                        _OpenRequestsNote(count: open, atLimit: atLimit),
                        const SizedBox(height: Sp.lg),
                      ],
                      _RequestForm(
                        key: _formKey,
                        sending: _sending,
                        disabledGobikerIds: _store.openGobikerIds,
                      ),
                    ],
                  ),
                ),
                // The one main action, always in the same spot.
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
                      onPressed: atLimit
                          ? null
                          : () => _formKey.currentState?.submit(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Says that other requests are open and where to find their answers (History), without
/// getting in the way of sending another.
class _OpenRequestsNote extends StatelessWidget {
  const _OpenRequestsNote({required this.count, required this.atLimit});

  final int count;
  final bool atLimit;

  @override
  Widget build(BuildContext context) {
    final text = atLimit
        ? 'You have $count open requests, the most you can have. Cancel one in '
              'History to ask another GoBiker.'
        : 'You have $count open ${count == 1 ? 'request' : 'requests'}. '
              'See their answers in History.';
    return Semantics(
      container: true,
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            atLimit ? Icons.info_rounded : Icons.history_rounded,
            size: 20,
            color: atLimit ? context.pal.orangeText : context.pal.muted,
          ),
          const SizedBox(width: Sp.md),
          Expanded(
            child: Text(
              text,
              style: T.secondary.muted(context).copyWith(
                color: atLimit ? context.pal.orangeText : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestForm extends StatefulWidget {
  const _RequestForm({
    super.key,
    required this.sending,
    this.disabledGobikerIds = const {},
  });

  /// The screen's button shows this while the request is being sent.
  final ValueNotifier<bool> sending;

  /// GoBikers who already have a request open from this person: shown, but not choosable.
  final Set<int> disabledGobikerIds;

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

  static List<String> get _barangays => kPickerBarangays;

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
    final picked = await showGobikerPicker(
      context,
      // Start with the GoBikers where the visit is; others are one tap away.
      startBarangay: _barangay ?? _homeBarangay(),
      selectedId: _gobiker?.id,
      disabledIds: widget.disabledGobikerIds,
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
    // Sent: back to where they came from. Its answer will show in History.
    if (error == null) Navigator.of(context).maybePop();
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
          Text(
            'Choose a GoBiker to visit you and check your blood pressure, '
            'pulse, temperature and more. They accept or decline in their '
            'app. For emergencies, use the SOS button instead.',
            style: T.secondary.muted(context),
          ),
          const SizedBox(height: Sp.xl),
          DropdownButtonFormField<String>(
            style: T.body.copyWith(color: context.pal.ink),
            dropdownColor: context.pal.card,
            initialValue: _barangay,
            isExpanded: true,
            decoration: inputDecoration(
              context,
              'Barangay',
              Icons.map_outlined,
            ),
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
            style: T.body.copyWith(color: context.pal.ink),
            cursorColor: context.pal.ink,
            controller: _address,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 255,
            decoration: inputDecoration(
              context,
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
              side: BorderSide(color: context.pal.line),
              selectedBackgroundColor: context.pal.ink,
              selectedForegroundColor: context.pal.card,
              foregroundColor: context.pal.ink,
            ),
          ),
          const SizedBox(height: Sp.lg),
          TextFormField(
            style: T.body.copyWith(color: context.pal.ink),
            cursorColor: context.pal.ink,
            controller: _reason,
            minLines: 3,
            maxLines: 5,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: inputDecoration(
              context,
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
          context,
          'Preferred date',
          Icons.event_rounded,
        ).copyWith(errorText: showError ? 'Choose a date' : null),
        child: Text(
          date == null ? 'Choose a date' : formatDate(date!),
          style: date == null
              ? T.body.copyWith(color: context.pal.muted)
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
            context,
            'GoBiker',
            Icons.directions_bike_rounded,
            suffix: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: context.pal.muted,
            ),
          ).copyWith(errorText: showError ? 'Choose a GoBiker' : null),
          child: Text(
            g == null ? 'Choose a GoBiker' : '${g.name} · ${g.barangay}',
            style: g == null
                ? T.body.copyWith(color: context.pal.muted)
                : T.body,
          ),
        ),
      ),
    );
  }
}
