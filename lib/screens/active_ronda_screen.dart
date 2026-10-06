import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/auth_service.dart';
import '../core/theme.dart';
import '../core/tracking_service.dart';
import '../widgets/app_text_field.dart';
import '../widgets/app_toast.dart';
import '../widgets/confirm_modal.dart';
import 'add_patient_screen.dart';
import 'global_state.dart';
import 'view_patient_screen.dart';
import 'login_screen.dart';
import '../core/emergency_flow.dart';

const List<String> _barangays = [
  'Angarian',
  'Asinan',
  'Bacabac',
  'Bañaga',
  'Bolaoen',
  'Buenlag',
  'Cabayaoasan',
  'Cayanga',
  'Gueset',
  'Hacienda',
  'Laguit Centro',
  'Laguit Padilla',
  'Magtaking',
  'Pangascasan',
  'Pantal',
  'Poblacion',
  'Polong',
  'Portic',
  'Salasa',
  'Salomague Norte',
  'Salomague Sur',
  'Samat',
  'San Francisco',
  'Umanday',
];

class ActiveRondaScreen extends StatefulWidget {
  const ActiveRondaScreen({super.key});

  @override
  State<ActiveRondaScreen> createState() => _ActiveRondaScreenState();
}

class _ActiveRondaScreenState extends State<ActiveRondaScreen>
    with SingleTickerProviderStateMixin {
  // The ronda was already started on the server by the dashboard,
  // so the clock starts as soon as this screen opens.
  final DateTime _startedAt = DateTime.now();
  late final String _startTime = DateFormat('hh:mm a').format(_startedAt);

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  Timer? _timer;
  String? _barangay;
  final List<Map<String, dynamic>> _todayPatients = [];

  @override
  void initState() {
    super.initState();

    final mine = AuthService.instance.currentUser?.barangay;
    _barangay = _barangays.contains(mine) ? mine : null;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    // If the server rejects the live location (expired login, etc.), tell the user.
    TrackingService.instance.onFatalError = _handleFatalError;
  }

  @override
  void dispose() {
    TrackingService.instance.onFatalError = null;
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  String get _duration {
    final d = DateTime.now().difference(_startedAt);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  //  actions

  bool _handlingFatal = false;

  Future<void> _handleFatalError(String message) async {
    if (_handlingFatal || !mounted) return;
    _handlingFatal = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          icon: const Icon(
            Icons.location_off_rounded,
            color: AppTheme.errorRed,
            size: 40,
          ),
          title: const Text('Tracking stopped'),
          content: Text('$message\n\nPlease log in again.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Log in again'),
            ),
          ],
        ),
      ),
    );

    await AuthService.instance.logout();
    globalPatients.clear();
    globalRondas.clear();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<bool> _confirmEndRonda() async {
    final shouldEnd = await ConfirmModal.show(
      context: context,
      icon: Icons.stop_circle_rounded,
      color: AppTheme.errorRed,
      title: 'End your ronda?',
      description: 'Your live location will stop being shared with the RHU admin and this ronda will be saved to your history.',
      confirmText: 'End Ronda',
      onConfirm: () {},
    );
    if (shouldEnd != true) return false;

    _timer?.cancel();
    await TrackingService.instance.stopRonda();

    // Save the completed shift to the history shown on the dashboard.
    globalRondas.add({
      'barangay': _barangay ?? 'Not specified',
      'date': DateFormat('MMMM d, yyyy').format(DateTime.now()),
      'startTime': _startTime,
      'endTime': DateFormat('hh:mm a').format(DateTime.now()),
      'endDateTime': DateTime.now(), // used for "minutes ago"
      'patientsCount': _todayPatients.length,
      'distance': TrackingService.instance.distanceKm, // real GPS distance
    });
    return true;
  }

  Future<void> _endRondaPressed() async {
    final ended = await _confirmEndRonda();
    if (ended && mounted) Navigator.of(context).pop();
  }

  Future<void> _addPatient() async {
    final created = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => AddPatientScreen(barangay: _barangay),
      ),
    );
    if (created == null || !mounted) return;

    setState(() {
      _todayPatients.add(created);
      globalPatients.insert(0, created);
    });
    AppToast.show(context, 'Patient record saved.', type: ToastType.success);
  }

  Future<void> _openPatientViewer(int index) async {
    final patient = _todayPatients[index];
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewPatientScreen(patient: patient),
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      if (result['action'] == 'delete') {
        _todayPatients.removeWhere((p) => p['id'] == patient['id']);
        globalPatients.removeWhere((p) => p['id'] == patient['id']);
        AppToast.show(context, 'Record deleted.', type: ToastType.success);
      } else if (result['action'] == 'update') {
        _todayPatients[index] = result['data'];
        final g = globalPatients.indexWhere((p) => p['id'] == patient['id']);
        if (g != -1) globalPatients[g] = result['data'];
        AppToast.show(context, 'Record updated.', type: ToastType.success);
      }
    });
  }

  // -------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _endRondaPressed(); // back button asks to end the ronda
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _heroCard(),
                    const SizedBox(height: 20),
                    AppDropdownField(
                      label: 'Barangay on ronda',
                      hint: 'Select barangay',
                      icon: Icons.location_on_outlined,
                      items: _barangays,
                      value: _barangay,
                      onChanged: (v) => setState(() => _barangay = v),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Text(
                          "TODAY'S PATIENT LOG",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: muted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.blue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_todayPatients.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_todayPatients.isEmpty)
                      _emptyLog(muted)
                    else
                      for (var i = 0; i < _todayPatients.length; i++)
                        _patientTile(theme, muted, i),
                  ],
                ),
              ),
              _bottomActions(theme, muted),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ pieces

  Widget _heroCard() {
    final km = TrackingService.instance.distanceKm;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.navy,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x261E1E48),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _pulseDot(),
              const SizedBox(width: 10),
              const Text(
                'RONDA IN PROGRESS',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _duration,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Text(
            'Duration',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 18),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              _heroStat('Started', _startTime),
              _heroStat('Patients', '${_todayPatients.length}'),
              _heroStat('Distance', '${km.toStringAsFixed(2)} km'),
            ],
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Icon(Icons.location_on_rounded, color: Colors.white70, size: 16),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Your live location is shared with the RHU admin.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pulseDot() {
    return SizedBox(
      width: 22,
      height: 22,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final v = _pulse.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 10 + 12 * v,
                height: 10 + 12 * v,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.successGreen.withValues(alpha: (1 - v) * 0.5),
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.successGreen,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _heroStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyLog(Color muted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.assignment_ind_outlined, size: 48, color: muted),
          const SizedBox(height: 12),
          const Text(
            'No patients logged yet',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap Add Patient to record your first check-up.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: muted),
          ),
        ],
      ),
    );
  }

  Widget _patientTile(ThemeData theme, Color muted, int index) {
    final p = _todayPatients[index];
    final name = p['name']?.toString() ?? 'Unnamed';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _openPatientViewer(index),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.blue.withValues(alpha: 0.12),
                child: Text(
                  _initials(name),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.blue,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${p['time'] ?? ''}',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomActions(ThemeData theme, Color muted) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: _barangay == null ? null : _addPatient,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text(
                'Add Patient',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            if (_barangay == null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Select a barangay to add patients.',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => EmergencyFlow.run(context),
                    icon: const Icon(Icons.warning_amber_rounded),
                    label: const Text(
                      'Emergency',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.errorRed,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _endRondaPressed,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text(
                      'End Ronda',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
