import 'package:flutter/material.dart';

import '../../core/appointments.dart';
import '../../core/auth_service.dart';
import 'app_colors.dart';
import 'emergency_request_screen.dart' show kLocations;
import 'patient_ui.dart';
import 'visit_record.dart' show formatDate;

const _green = Color(0xFF2E9E5B);

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
    color: _green,
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
    color: AppColors.orange,
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

  @override
  void initState() {
    super.initState();
    _store.load();
  }

  Future<void> _cancel(Appointment a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this visit?'),
        content: Text(
          a.gobikerName == null
              ? 'Your request will be withdrawn.'
              : '${a.gobikerName} will be told not to come.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Cancel visit',
              style: TextStyle(color: AppColors.red),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final error = await _store.cancel(a.id);
    if (!mounted) return;
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
      appBar: patientAppBar(context, 'Home Visit'),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            if (!_store.loaded && _store.loading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.red),
              );
            }
            if (!_store.loaded && _store.error != null) {
              return _LoadError(message: _store.error!, onRetry: _store.load);
            }

            final current = _store.current;
            final past = _store.appointments.where((a) => !a.isOpen).toList();

            return RefreshIndicator(
              color: AppColors.red,
              onRefresh: _store.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (current != null)
                    _StatusCard(
                      appointment: current,
                      onCancel: () => _cancel(current),
                    )
                  else
                    const _RequestForm(),
                  if (past.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'PAST REQUESTS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final a in past) _PastTile(appointment: a),
                  ],
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
  const _StatusCard({required this.appointment, required this.onCancel});
  final Appointment appointment;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final s = _statusStyle(a);
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: cardDecoration().copyWith(
          border: Border.all(color: s.color.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(s.icon, color: s.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    a.statusLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: s.color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              s.help,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: AppColors.textDark,
              ),
            ),
            const Divider(height: 24),
            _row(
              Icons.event_rounded,
              '${formatDate(a.preferredDate)} · ${a.windowLabel}',
            ),
            _row(Icons.home_outlined, '${a.address}, ${a.barangay}'),
            _row(Icons.notes_rounded, a.reason),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.red,
                  side: const BorderSide(color: AppColors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Cancel visit',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13.5, color: AppColors.textDark),
          ),
        ),
      ],
    ),
  );
}

class _PastTile extends StatelessWidget {
  const _PastTile({required this.appointment});
  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final s = _statusStyle(a);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: cardDecoration(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(s.icon, color: s.color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${a.statusLabel} · ${formatDate(a.preferredDate)}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  a.status == 'declined' ? s.help : a.reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestForm extends StatefulWidget {
  const _RequestForm();

  @override
  State<_RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends State<_RequestForm> {
  final _form = GlobalKey<FormState>();
  final _address = TextEditingController();
  final _reason = TextEditingController();
  late String? _barangay = _homeBarangay();
  DateTime? _date;
  String _window = 'morning';
  bool _sending = false;

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
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    final valid = _form.currentState!.validate();
    if (_date == null) setState(() {}); // show the date error
    if (!valid || _date == null) return;

    setState(() => _sending = true);
    final error = await ResidentAppointments.instance.request(
      barangay: _barangay!,
      address: _address.text,
      date: _date!,
      window: _window,
      reason: _reason.text,
    );
    if (!mounted) return;
    setState(() => _sending = false);
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
          const Text(
            'Request a home check-up',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'A GoBiker in your barangay will visit to check your blood '
            'pressure, pulse, temperature and more. For emergencies, use the '
            'SOS button instead.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 18),
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
          const SizedBox(height: 14),
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
          const SizedBox(height: 14),
          _DateField(
            date: _date,
            onTap: _pickDate,
            showError: _date == null && _form.currentState != null,
          ),
          const SizedBox(height: 14),
          const Text(
            'Time of day',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
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
              selectedBackgroundColor: AppColors.redSoft,
              selectedForegroundColor: AppColors.red,
            ),
          ),
          const SizedBox(height: 14),
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
          const SizedBox(height: 8),
          primaryButton(
            label: 'REQUEST VISIT',
            loading: _sending,
            onPressed: _submit,
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
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: inputDecoration(
          'Preferred date',
          Icons.event_rounded,
        ).copyWith(errorText: showError ? 'Choose a date' : null),
        child: Text(
          date == null ? 'Choose a date' : formatDate(date!),
          style: TextStyle(
            fontSize: 15,
            color: date == null ? AppColors.textMuted : AppColors.textDark,
          ),
        ),
      ),
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 52,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: AppColors.red,
            ),
            child: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}
