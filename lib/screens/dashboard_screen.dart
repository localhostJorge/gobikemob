import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/auth_service.dart';
import '../core/greeting.dart';
import '../core/theme.dart';
import '../core/tracking_service.dart';
import '../widgets/app_toast.dart';
import '../widgets/confirm_modal.dart';
import '../widgets/fade_in_slide.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/profile_panel.dart';
import '../widgets/slide_to_start.dart';
import 'active_ronda_screen.dart';
import 'global_state.dart';
import 'patient_management_screen.dart';
import '../core/ronda_store.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final SlideToStartController _slider = SlideToStartController();
  bool _starting = false;
  bool _resuming = false;
  bool _profileOpen = false;
  SavedRonda? _savedRonda; // a ronda that was left open (app was closed/killed)

  // TODO(api): the schedule and announcement should come from the server.
  static const String _sampleSchedule = '8:00 AM - 12:00 PM';
  static const String _sampleAnnouncementTitle = 'Ronda Schedule Update';
  static const String _sampleAnnouncementBody =
      "Tomorrow's Ronda will start at 7:30 AM instead of 8:00 AM.";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedRonda();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh the greeting when the app comes back to the foreground.
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  // ------------------------------------------------------------------ actions
  /// Looks for a ronda that was left open and shows the Resume card.
  Future<void> _loadSavedRonda() async {
    // If an earlier "End ronda" never reached the server (offline), retry now.
    await TrackingService.instance.flushPendingStop();
    if (!mounted) return;

    // Tracking is already running in this session, so nothing to resume.
    if (TrackingService.instance.isActive) {
      setState(() => _savedRonda = null);
      return;
    }

    final saved = await RondaStore.load();
    if (!mounted) return;
    if (saved == null) {
      setState(() => _savedRonda = null);
      return;
    }

    // Ask Laravel if the ronda is still open. If the server says it is not,
    // the saved copy is stale, so delete it.
    final res = await AuthService.instance.callAuthed('GET', '/gobiker/active');
    if (!mounted) return;
    if (res.ok && res.body['active'] == false) {
      await RondaStore.clear();
      if (!mounted) return;
      setState(() => _savedRonda = null);
      return;
    }

    // Server says "active", or we are offline: show the card either way.
    setState(() => _savedRonda = saved);
  }

  /// Continue the ronda without restarting it on the server.
  Future<void> _resumeRonda() async {
    final saved = _savedRonda;
    if (saved == null) return;

    setState(() => _resuming = true);
    final error = await TrackingService.instance.resumeRonda(saved);
    if (!mounted) return;
    setState(() => _resuming = false);

    if (error != null) {
      AppToast.show(context, error, type: ToastType.error);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActiveRondaScreen(resumeFrom: saved),
      ),
    );
    if (!mounted) return;
    _slider.reset();
    await _loadSavedRonda(); // card disappears if the ronda was ended
    if (mounted) setState(() {}); // refresh today's metrics
  }

  /// Close the open ronda without resuming it.
  Future<void> _endSavedRonda() async {
    final confirmed = await ConfirmModal.show(
      context: context,
      icon: Icons.stop_circle_rounded,
      color: AppTheme.errorRed,
      title: 'End this ronda?',
      description:
          'This closes your open ronda. Live location sharing stays off.',
      confirmText: 'End Ronda',
      onConfirm: () {},
    );
    if (confirmed != true || !mounted) return;

    await RondaStore.clear();
    await RondaStore.setPendingStop(true);
    await TrackingService.instance.flushPendingStop();
    if (!mounted) return;
    setState(() => _savedRonda = null);
    AppToast.show(context, 'Ronda ended.', type: ToastType.success);
  }

  Future<void> _openProfile() async {
    setState(() => _profileOpen = true);
    await ProfilePanel.show(context);
    if (mounted) setState(() => _profileOpen = false);
  }

  void _openPatients() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PatientManagementScreen()),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _onSlideComplete() async {
    if (_savedRonda != null) {
      _slider.reset();
      AppToast.show(
        context,
        'Resume or end your open ronda first.',
        type: ToastType.info,
      );
      return;
    }

    final confirmed = await ConfirmModal.show(
      context: context,
      icon: Icons.directions_bike_rounded,
      color: AppTheme.blue,
      title: 'Start your ronda?',
      description:
          'Your location will be shared with the Go Bike admin while the ronda is active. '
          'Visit each assigned household and record your findings. You can end the ronda anytime.',
      confirmText: 'Start Ronda',
      onConfirm: () {},
    );

    if (confirmed != true) {
      _slider.reset(); // Cancel (or tapped outside): thumb slides back
      return;
    }
    if (!mounted) return;

    setState(() => _starting = true);
    final error = await TrackingService.instance.startRonda();
    if (!mounted) return;
    setState(() => _starting = false);

    if (error != null) {
      _slider.reset();
      AppToast.show(context, error, type: ToastType.error);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ActiveRondaScreen()),
    );
    if (!mounted) return;
    _slider.reset();
    setState(() {}); // refresh today's metrics
  }

  Future<void> _onEmergency() async {
    final confirmed = await ConfirmModal.show(
      context: context,
      icon: Icons.warning_amber_rounded,
      color: AppTheme.errorRed,
      title: 'Send emergency alert?',
      description: 'This immediately alerts the admin with your current location. Use only for real emergencies.',
      confirmText: 'Send Alert',
      onConfirm: () {},
    );
    if (confirmed != true || !mounted) return;

    // TODO(api): the emergency alert endpoint is built in step 3C.
    AppToast.show(
      context,
      'Alerts to the admin are not connected yet. For a real emergency, call 911.',
      type: ToastType.error,
    );
  }

  void _onAppointments() {
    // TODO(api): the Appointments screen is built in step 3C.
    AppToast.show(
      context,
      'Appointments are coming in the next update.',
      type: ToastType.info,
    );
  }

  void _showMessageAdminSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _MessageAdminSheet(rootContext: context),
    );
  }

  void _showRondaHistorySheet() {
    final rondas = globalRondas.reversed.toList(); // newest first
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final muted = Theme.of(ctx).colorScheme.onSurface
            .withValues(alpha: 0.6);
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ronda History',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                if (rondas.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            size: 40,
                            color: muted,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No completed rondas yet.',
                            style: TextStyle(color: muted),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: rondas.length,
                      separatorBuilder: (_, _) => const Divider(height: 24),
                      itemBuilder: (context, index) {
                        final r = rondas[index];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppTheme.successGreen,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Brgy. ${r['barangay']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${r['date']} • ${r['startTime']} - ${r['endTime']}\n'
                                    'Patients: ${r['patientsCount']} • ${(r['distance'] as double).toStringAsFixed(1)} km',
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _lastRondaText() {
    if (globalRondas.isEmpty) return 'No rondas completed yet';

    final DateTime lastTime = globalRondas.last['endDateTime'];
    final diff = DateTime.now().difference(lastTime);

    if (diff.inMinutes == 0) return 'Last ronda: just now';
    if (diff.inMinutes < 60) return 'Last ronda: ${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return 'Last ronda: ${diff.inHours} hours ago';
    return 'Last ronda: ${diff.inDays} days ago';
  }

  // -------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final user = AuthService.instance.currentUser;

    final barangay = (user?.barangay != null && user!.barangay!.isNotEmpty)
        ? user.barangay!
        : 'Not set';

    // Today's metrics
    final todayStr = DateFormat('MMMM d, yyyy').format(DateTime.now());
    final todaysRondas = globalRondas
        .where((r) => r['date'] == todayStr)
        .toList();
    final int todayPatients = todaysRondas.fold(
      0,
      (sum, r) => sum + (r['patientsCount'] as int),
    );
    final double todayDistance = todaysRondas.fold(
      0.0,
      (sum, r) => sum + (r['distance'] as double),
    );

    return LoadingOverlay(
      isLoading: _starting || _resuming,
      message: _resuming ? 'Resuming ronda...' : 'Starting ronda...',
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // 1) Greeting header
              FadeInSlide(
                offset: const Offset(0, -12),
                child: _buildHeader(theme, muted, user?.firstName ?? 'there'),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 2) Today's assignment (primary)
                      FadeInSlide(
                        delay: const Duration(milliseconds: 80),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_savedRonda != null) ...[
                              _sectionTitle('OPEN RONDA', muted),
                              _buildResumeCard(theme, muted),
                              const SizedBox(height: 24),
                            ],
                            _sectionTitle("TODAY'S ASSIGNMENT", muted),
                            _buildAssignmentCard(theme, muted, barangay),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 3) Today's summary
                      FadeInSlide(
                        delay: const Duration(milliseconds: 160),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle("TODAY'S SUMMARY", muted),
                            Row(
                              children: [
                                Expanded(
                                  child: _summaryCard(
                                    theme,
                                    muted,
                                    icon: Icons.people_alt_rounded,
                                    color: AppTheme.blue,
                                    value: '$todayPatients',
                                    label: 'Visited',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _summaryCard(
                                    theme,
                                    muted,
                                    icon: Icons.event_note_rounded,
                                    color: AppTheme.orange,
                                    value: '0',
                                    label: 'Appointments',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _summaryCard(
                                    theme,
                                    muted,
                                    icon: Icons.route_rounded,
                                    color: AppTheme.successGreen,
                                    value:
                                        '${todayDistance.toStringAsFixed(1)} km',
                                    label: 'Distance',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 4) Quick actions
                      FadeInSlide(
                        delay: const Duration(milliseconds: 240),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle('QUICK ACTIONS', muted),
                            Row(
                              children: [
                                Expanded(
                                  child: _quickAction(
                                    theme,
                                    icon: Icons.people_alt_rounded,
                                    color: AppTheme.blue,
                                    label: 'Patients',
                                    onTap: _openPatients,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _quickAction(
                                    theme,
                                    icon: Icons.warning_amber_rounded,
                                    color: AppTheme.errorRed,
                                    label: 'Emergency',
                                    onTap: _onEmergency,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _quickAction(
                                    theme,
                                    icon: Icons.event_note_rounded,
                                    color: AppTheme.orange,
                                    label: 'Appointments',
                                    onTap: _onAppointments,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 5) Announcements
                      FadeInSlide(
                        delay: const Duration(milliseconds: 320),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle('ANNOUNCEMENTS', muted),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: _cardDecoration(theme),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _iconBadge(
                                    Icons.campaign_rounded,
                                    AppTheme.orange,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          _sampleAnnouncementTitle,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _sampleAnnouncementBody,
                                          style: TextStyle(
                                            fontSize: 13,
                                            height: 1.4,
                                            color: muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 6) Secondary buttons
                      FadeInSlide(
                        delay: const Duration(milliseconds: 400),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _showMessageAdminSheet,
                                icon: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 20,
                                ),
                                label: const Text('Message Admin'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(50),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _showRondaHistorySheet,
                                icon: const Icon(
                                  Icons.history_rounded,
                                  size: 20,
                                ),
                                label: const Text('Ronda History'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(50),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom bar (Profile at the far right)
              FadeInSlide(
                delay: const Duration(milliseconds: 480),
                offset: const Offset(0, 24),
                child: _buildBottomBar(theme, muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ pieces

  BoxDecoration _cardDecoration(ThemeData theme, {bool shadow = false}) {
    final isLight = theme.brightness == Brightness.light;
    return BoxDecoration(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: theme.dividerColor),
      boxShadow: (shadow && isLight)
          ? const [
              BoxShadow(
                color: Color(0x141E1E48),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ]
          : null,
    );
  }

  Widget _sectionTitle(String text, Color muted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: muted,
        ),
      ),
    );
  }

  Widget _iconBadge(IconData icon, Color color) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildHeader(ThemeData theme, Color muted, String firstName) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Container(
            padding: isDark
                ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                : EdgeInsets.zero,
            decoration: BoxDecoration(
              color: isDark ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset(
              'assets/images/logo.png',
              height: 36,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.directions_bike_rounded,
                color: AppTheme.blue,
                size: 32,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greetingForNow(),
                  style: TextStyle(fontSize: 13, color: muted),
                ),
                const SizedBox(height: 2),
                Text(
                  firstName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumeCard(ThemeData theme, Color muted) {
    final saved = _savedRonda!;
    final started = DateFormat('hh:mm a').format(saved.startedAt);
    final km = (saved.distanceMeters / 1000).toStringAsFixed(2);
    final place = (saved.barangay != null && saved.barangay!.isNotEmpty)
        ? 'Brgy. ${saved.barangay}'
        : 'Ronda in progress';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.orange.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBadge(Icons.history_rounded, AppTheme.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'You have an open ronda',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$place • Started $started\n'
                      '${saved.patientsCount} patients • $km km',
                      style: TextStyle(fontSize: 13, height: 1.4, color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _endSavedRonda,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorRed,
                    side: const BorderSide(color: AppTheme.errorRed),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('End it'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _resumeRonda,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text(
                    'Resume ronda',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard(ThemeData theme, Color muted, String barangay) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(theme, shadow: true),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _iconBadge(Icons.location_on_rounded, AppTheme.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Barangay $barangay',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Schedule: $_sampleSchedule',
                      style: TextStyle(fontSize: 13, color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SlideToStart(controller: _slider, onCompleted: _onSlideComplete),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.schedule_rounded, size: 14, color: muted),
              const SizedBox(width: 6),
              Text(
                _lastRondaText(),
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(
    ThemeData theme,
    Color muted, {
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: _cardDecoration(theme),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ],
      ),
    );
  }

  Widget _quickAction(
    ThemeData theme, {
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: _cardDecoration(theme),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme, Color muted) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: _cardDecoration(
        theme,
        shadow: true,
      ).copyWith(borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          _NavItem(
            icon: Icons.home_rounded,
            label: 'Home',
            selected: !_profileOpen,
            muted: muted,
            onTap: () {},
          ),
          _NavItem(
            icon: Icons.people_alt_rounded,
            label: 'Patients',
            selected: false,
            muted: muted,
            onTap: _openPatients,
          ),
          _NavItem(
            icon: Icons.person_rounded,
            label: 'Profile',
            selected: _profileOpen,
            muted: muted,
            onTap: _openProfile,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.muted,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.blue : muted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.blue.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 26, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Message Admin bottom sheet — sends a real POST to /gobiker/message
// ---------------------------------------------------------------------------
class _MessageAdminSheet extends StatefulWidget {
  const _MessageAdminSheet({required this.rootContext});

  /// The dashboard's BuildContext, which stays alive after the sheet closes.
  final BuildContext rootContext;

  @override
  State<_MessageAdminSheet> createState() => _MessageAdminSheetState();
}

class _MessageAdminSheetState extends State<_MessageAdminSheet> {
  final _ctrl = TextEditingController();
  bool _sending = false;
  static const int _maxChars = 500;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      AppToast.show(context, 'Please type a message first.', type: ToastType.error);
      return;
    }
    // Capture before the async gap (lint: use_build_context_synchronously)
    final rootCtx = widget.rootContext;
    setState(() => _sending = true);

    final res = await AuthService.instance.callAuthed(
      'POST',
      '/gobiker/message',
      body: {'message': text},
    );

    if (!mounted) return;
    setState(() => _sending = false);

    if (res.ok) {
      Navigator.of(context).pop();
      if (rootCtx.mounted) {
        AppToast.show(
          rootCtx,
          'Message sent to admin!',
          type: ToastType.success,
        );
      }
    } else {
      AppToast.show(context, res.message, type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sheet header
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.blue.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_rounded,
                  color: AppTheme.blue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Message Admin',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Send a report or question to the Go Bike admin.',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Message field
          ListenableBuilder(
            listenable: _ctrl,
            builder: (context, _) {
              final count = _ctrl.text.length;
              final overLimit = count > _maxChars;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextField(
                    controller: _ctrl,
                    maxLines: 5,
                    minLines: 4,
                    maxLength: _maxChars,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: 'Type your message here…',
                      alignLabelWithHint: true,
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$count / $_maxChars',
                    style: TextStyle(
                      fontSize: 11,
                      color: overLimit ? AppTheme.errorRed : muted,
                      fontWeight: overLimit ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Send button
          ElevatedButton(
            onPressed: _sending ? null : _send,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: _sending
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Send Message',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }
}
