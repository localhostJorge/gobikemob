import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../core/announcements.dart';
import '../core/appointments.dart';
import '../core/auth_service.dart';
import '../core/emergency_flow.dart';
import '../core/emergency_watcher.dart';
import '../core/follow_up_alerts.dart';
import '../core/greeting.dart';
import '../core/gobiker_messages.dart';
import '../core/live_map.dart';
import '../core/presence_service.dart';
import '../core/push_service.dart';
import '../core/sos_actions.dart';
import '../core/theme.dart';
import '../core/tracking_service.dart';
import '../widgets/app_toast.dart';
import '../widgets/assigned_sos_card.dart';
import '../widgets/bottom_gap.dart';
import '../widgets/ronda_hero.dart';
import '../widgets/ronda_nav_bar.dart';
import 'patient/app_colors.dart';
import 'patient/ui_kit.dart';
import '../widgets/confirm_modal.dart';
import '../widgets/emergency_status_card.dart';
import '../widgets/fade_in_slide.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/profile_panel.dart';
import '../widgets/slide_to_start.dart';
import 'active_ronda_screen.dart';
import 'announcements_screen.dart';
import 'appointments_screen.dart';
import 'global_state.dart';
import 'gobiker_history_screen.dart';
import 'gobiker_messages_screen.dart';
import 'live_map_screen.dart';
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

  /// The open tab: 0 Home, 1 Map, 2 History, 3 Profile.
  int _tab = 0;

  /// An SOS to show when the Map tab opens (from the Assigned SOS card).
  int? _mapFocus;

  /// An SOS to show the way to when the Map tab opens (its Directions button).
  int? _mapDirections;

  /// History and Profile are built the first time they are opened, then kept, so
  /// their scroll position and filters survive switching tabs.
  bool _historyOpened = false;
  bool _profileOpened = false;
  SavedRonda? _savedRonda; // a ronda that was left open (app was closed/killed)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedRonda();
    _loadFinishedRondas(); // today's summary and History, kept across restarts
    FollowUpAlerts.instance.refresh(); // admin decisions about patients
    EmergencyWatcher.instance
        .load(); // an emergency the admin may have answered
    Announcements.instance.refresh(); // what the admin announced
    GobikerAppointments.instance
      ..addListener(_onAppointmentsChanged)
      ..load(); // visit requests from residents
    GobikerSos.instance.addListener(_onAppointmentsChanged);
    // SOS requests the admin assigned to this GoBiker, and an alert for one
    // sent while the app was closed or the push never came.
    _loadSos();
    PresenceService.instance.start(); // on the live map while the app is open
    _refreshUser(); // the admin may have changed the barangay
  }

  /// The rondas this GoBiker finished, from the phone. They used to live in memory only, so
  /// a restart emptied today's summary and the history.
  Future<void> _loadFinishedRondas() async {
    final userId = AuthService.instance.currentUser?.id ?? 0;
    final saved = await RondaStore.loadFinished(userId);
    if (!mounted) return;
    setState(() => globalRondas = saved);
  }

  Future<void> _loadSos() async {
    await GobikerSos.instance.load();
    if (mounted) await PushService.instance.checkMissedAssignments();
  }

  void _onAppointmentsChanged() {
    if (mounted) setState(() {}); // the Appointments counter
  }

  Future<void> _refreshUser() async {
    await AuthService.instance.refreshUser();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    GobikerAppointments.instance.removeListener(_onAppointmentsChanged);
    GobikerSos.instance.removeListener(_onAppointmentsChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh the greeting when the app comes back to the foreground.
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
      FollowUpAlerts.instance.refresh();
      Announcements.instance.refresh();
      GobikerAppointments.instance.load();
      _loadSos();
      _refreshUser();
      if (EmergencyWatcher.instance.isOpen) EmergencyWatcher.instance.check();
    }
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
      title: 'Are you already done?',
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

  /// Switches tabs: no slide, the bottom bar stays.
  void _selectTab(int tab, {int? mapFocus, int? mapDirections}) {
    if (tab == _tab && mapFocus == null && mapDirections == null) return;
    // Leaving the map: catch up on the SOS requests it may have changed.
    if (_tab == 1 && tab != 1) GobikerSos.instance.load();
    setState(() {
      _tab = tab;
      if (tab == 1) {
        _mapFocus = mapFocus;
        _mapDirections = mapDirections;
      }
      if (tab == 2) _historyOpened = true;
      if (tab == 3) _profileOpened = true;
    });
  }

  /// Everything Home shows, fetched again (pull down to refresh).
  Future<void> _refreshHome() async {
    await Future.wait([
      FollowUpAlerts.instance.refresh(),
      Announcements.instance.refresh(),
      GobikerAppointments.instance.load(),
      GobikerSos.instance.load(),
      _refreshUser(),
      _loadSavedRonda(),
      _loadFinishedRondas(),
      if (EmergencyWatcher.instance.isOpen) EmergencyWatcher.instance.check(),
    ]);
    if (mounted) setState(() {});
  }

  void _openPatients() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PatientManagementScreen()),
    ).then((_) {
      if (mounted) setState(() {});
      FollowUpAlerts.instance.refresh();
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
    await EmergencyFlow.run(context);
  }

  void _onAppointments() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AppointmentsScreen()),
    );
  }

  void _onDirections(AssignedSos sos) => _selectTab(1, mapDirections: sos.id);

  Future<void> _resolveSos(AssignedSos sos) async {
    var confirmed = false;
    await ConfirmModal.show(
      context: context,
      icon: Icons.check_circle_rounded,
      color: AppTheme.successGreen,
      title: 'Mark this SOS as resolved?',
      description:
          '${sos.residentName} will be told the emergency is over and asked to rate your response.',
      confirmText: 'Resolve',
      onConfirm: () => confirmed = true,
    );
    if (!confirmed || !mounted) return;
    final error = await GobikerSos.instance.resolve(sos.id);
    if (!mounted) return;
    AppToast.show(
      context,
      error ?? 'SOS resolved. Thank you for responding!',
      type: error == null ? ToastType.success : ToastType.error,
    );
  }

  /// Turns the SOS down, with a reason for the admin.
  Future<void> _declineSos(AssignedSos sos) =>
      declineAssignedSos(context, sos.id);

  /// SOS requests the admin sent this GoBiker to: directions, resolve, decline.
  Widget _buildAssignedSos(ThemeData theme, Color muted) {
    final open = GobikerSos.instance.open;
    if (open.isEmpty) return const SizedBox.shrink();
    final me = PresenceService.instance.latest.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Assigned SOS', muted),
        for (final sos in open)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AssignedSosCard(
              sos: sos,
              from: me == null ? null : LatLng(me.latitude, me.longitude),
              onDirections: () => _onDirections(sos),
              onResolve: () => _resolveSos(sos),
              onDecline: () => _declineSos(sos),
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  /// Opens the full conversation with the admin: sent messages and their
  /// replies, with the send bar at the bottom.
  void _openMessagesThread() {
    GobikerMessages.instance.markRepliesSeen();
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const GobikerMessagesScreen()));
  }

  /// Home visits finished today. The check-up recorded at a visit is not in any ronda, so each
  /// one counts here, once.
  int _homeVisitsDoneToday() {
    final now = DateTime.now();
    return GobikerAppointments.instance.mine.where((a) {
      final done = a.completedAt;
      return a.status == 'completed' &&
          done != null &&
          done.year == now.year &&
          done.month == now.month &&
          done.day == now.day;
    }).length;
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
    final int todayVisited = todayPatients + _homeVisitsDoneToday();

    return LoadingOverlay(
      isLoading: _starting || _resuming,
      message: _resuming ? 'Resuming ronda...' : 'Starting ronda...',
      // Back on Map, History or Profile goes to Home first, not out of the app.
      child: PopScope(
        canPop: _tab == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _selectTab(0);
        },
        child: Scaffold(
          // The floating bottom bar reserves the phone's navigation area itself.
          bottomNavigationBar: _buildBottomBar(),
          body: IndexedStack(
            index: _tab,
            children: [
              _buildHome(
                theme,
                muted,
                user?.firstName ?? 'there',
                barangay,
                todayVisited,
                todayDistance,
              ),
              // The map runs (GPS, refreshing every few seconds) only while it is open.
              _tab == 1
                  ? LiveMapScreen(
                      key: ValueKey('map-$_mapFocus-$_mapDirections'),
                      focusSosId: _mapFocus,
                      directionsSosId: _mapDirections,
                    )
                  : const SizedBox.shrink(),
              _historyOpened
                  ? const GobikerHistoryScreen()
                  : const SizedBox.shrink(),
              _profileOpened
                  ? const SafeArea(bottom: false, child: GobikerProfileTab())
                  : const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }

  /// Home: the navy header, then the day's work. Pull down to refresh.
  Widget _buildHome(
    ThemeData theme,
    Color muted,
    String firstName,
    String barangay,
    int todayVisited,
    double todayDistance,
  ) {
    return Column(
      children: [
        // 1) Greeting header
        _buildHeader(firstName, barangay),

        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshHome,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                Sp.gutter,
                Sp.xl,
                Sp.gutter,
                Sp.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The admin's answer to an emergency alert, if one was sent
                  const EmergencyStatusCard(),

                  // SOS requests the admin sent this GoBiker to
                  _buildAssignedSos(theme, muted),

                  // 2) Today's assignment (primary)
                  FadeInSlide(
                    delay: const Duration(milliseconds: 80),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_savedRonda != null) ...[
                          _sectionTitle('Open ronda', muted),
                          _buildResumeCard(theme, muted),
                          const SizedBox(height: 24),
                        ],
                        _sectionTitle("Today's assignment", muted),
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
                        _sectionTitle("Today's summary", muted),
                        _summaryStrip(theme, muted, [
                          ('$todayVisited', 'Visited'),
                          (
                            '${GobikerAppointments.instance.openCount}',
                            'Appointments',
                          ),
                          (
                            '${todayDistance.toStringAsFixed(1)} km',
                            'Distance',
                          ),
                        ]),
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
                        _sectionTitle('Quick actions', muted),
                        ListenableBuilder(
                          listenable: FollowUpAlerts.instance,
                          builder: (context, _) =>
                              _followUpNotice(theme, muted),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: ListenableBuilder(
                                listenable: FollowUpAlerts.instance,
                                builder: (context, _) => _quickAction(
                                  theme,
                                  icon: Icons.people_alt_rounded,
                                  color: AppTheme.blue,
                                  label: 'Patients',
                                  badge: FollowUpAlerts.instance.count,
                                  onTap: _openPatients,
                                ),
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
                                icon: Icons.calendar_month_rounded,
                                color: AppTheme.blue,
                                label: 'Appointments',
                                badge:
                                    GobikerAppointments
                                        .instance
                                        .requests
                                        .length +
                                    GobikerAppointments
                                        .instance
                                        .available
                                        .length,
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
                        _sectionTitle('Announcements', muted),
                        ListenableBuilder(
                          listenable: Announcements.instance,
                          builder: (context, _) =>
                              _announcementsSection(theme, muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 6) Secondary button (History is in the bottom bar). Opens the
                  // message thread; a red badge shows unseen admin replies.
                  FadeInSlide(
                    delay: const Duration(milliseconds: 400),
                    child: ListenableBuilder(
                      listenable: GobikerMessages.instance,
                      builder: (context, _) {
                        final unseen =
                            GobikerMessages.instance.unseenReplyCount;
                        return OutlinedButton.icon(
                          onPressed: _openMessagesThread,
                          icon: Badge(
                            isLabelVisible: unseen > 0,
                            label: Text('$unseen'),
                            backgroundColor: AppColors.blue,
                            textStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                            offset: const Offset(-4, 4),
                            child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 20,
                            ),
                          ),
                          label: const Text('Message Admin'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ pieces

  BoxDecoration _cardDecoration(ThemeData theme, {bool shadow = false}) {
    final isLight = theme.brightness == Brightness.light;
    return BoxDecoration(
      color: context.pal.card,
      borderRadius: BorderRadius.circular(Rd.card),
      border: Border.all(color: context.pal.line),
      boxShadow: (shadow && isLight)
          ? [
              BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ]
          : null,
    );
  }

  /// A wash of a status colour that still reads as a surface in both themes.
  /// Dark mode needs more of it: a tenth of yellow over near-black is mud.
  Color _tint(ThemeData theme, Color color) => color.withValues(
    alpha: theme.brightness == Brightness.dark ? 0.18 : 0.10,
  );

  /// A section heading, as on the resident screens: "Today's assignment".
  Widget _sectionTitle(String text, Color muted) => SectionHeader(text);

  Widget _iconBadge(IconData icon, Color color) =>
      IconTile(icon, color: color, size: 44);

  /// The navy Go Bike band: greeting, name, the barangay this GoBiker covers, and
  /// an "On ronda" pill (with the logo's orange dot) while a ronda is open.
  Widget _buildHeader(String firstName, String barangay) {
    return RondaHero(
      eyebrow: greetingForNow(),
      title: firstName,
      subtitle: barangay == 'Not set'
          ? 'No barangay assigned yet'
          : 'Barangay $barangay',
      subtitleIcon: Icons.place_outlined,
      trailing: _savedRonda == null ? null : const _OnRondaPill(),
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
        color: _tint(theme, AppTheme.orange),
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
                child: Text(
                  'Barangay $barangay',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
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

  /// Today's numbers as one flat strip: no icons, borders or shadow, so it
  /// reads as information and not as more buttons like the quick actions.
  Widget _summaryStrip(
    ThemeData theme,
    Color muted,
    List<(String value, String label)> stats,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: context.pal.brandSoft,
        borderRadius: BorderRadius.circular(Rd.card),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0)
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: context.pal.brand.withValues(alpha: 0.2),
                ),
              Expanded(
                child: Semantics(
                  label: '${stats[i].$2}: ${stats[i].$1}',
                  excludeSemantics: true,
                  child: Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          stats[i].$1,
                          style: T.stat.copyWith(
                            fontSize: 22,
                            color: context.pal.heading,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stats[i].$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _quickAction(
    ThemeData theme, {
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: _cardDecoration(theme),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconTile(icon, color: color, size: 48),
                if (badge > 0)
                  Positioned(top: -6, right: -8, child: _CountBadge(badge)),
              ],
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

  /// The admin's announcements: the newest one, a count of the rest, and a "New" tag.
  Widget _announcementsSection(ThemeData theme, Color muted) {
    final announcements = Announcements.instance;
    final latest = announcements.latest;
    final more = announcements.items.length - 1;
    final unseen = announcements.unseenCount;

    return InkWell(
      onTap: _openAnnouncements,
      borderRadius: BorderRadius.circular(16),
      child: latest == null
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(theme),
              child: Row(
                children: [
                  _iconBadge(Icons.campaign_outlined, muted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No announcements right now. Messages from the admin will appear here.',
                      style: TextStyle(fontSize: 13, height: 1.4, color: muted),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnnouncementCard(
                  announcement: latest,
                  isNew: announcements.isNew(latest),
                  maxLines: 3,
                ),
                if (more > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                    child: Text(
                      unseen > 1
                          ? '$more more · $unseen new — tap to read all'
                          : '$more more — tap to read all',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.pal.brand,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  void _openAnnouncements() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AnnouncementsScreen()),
    );
  }

  /// "Admin update": patients the admin decided about, until the GoBiker looks.
  Widget _followUpNotice(ThemeData theme, Color muted) {
    final count = FollowUpAlerts.instance.count;
    if (count == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: _openPatients,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.pal.brandSoft,
            borderRadius: BorderRadius.circular(Rd.card),
            border: Border.all(
              color: context.pal.brand.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.campaign_rounded, color: context.pal.brand),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == 1
                          ? '1 update from the admin'
                          : '$count updates from the admin',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'The admin decided whether to keep checking '
                      '${count == 1 ? 'a patient' : 'some patients'}. Tap to see.',
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

  Widget _buildBottomBar() {
    // Four tabs; the bar stays on every one of them.
    return RondaNavBar(
      selectedIndex: _tab,
      bottomInset: bottomGap(context),
      onTap: _selectTab,
      items: [
        const RondaNavItem(
          label: 'Home',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
        ),
        RondaNavItem(
          label: 'Map',
          icon: Icons.map_outlined,
          selectedIcon: Icons.map_rounded,
          // Open SOS requests assigned to this GoBiker.
          badge: GobikerSos.instance.open.length,
          semanticLabel: GobikerSos.instance.open.isEmpty
              ? 'Map'
              : 'Map, ${GobikerSos.instance.open.length} open SOS',
        ),
        const RondaNavItem(label: 'History', icon: Icons.history_rounded),
        const RondaNavItem(
          label: 'Profile',
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers below
// ---------------------------------------------------------------------------

/// Red bubble with a number, for "something new here".
class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.blue,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: context.pal.card, width: 1.5),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

/// "On ronda", with the orange dot from the logo: shown in the header while a
/// ronda is open.
class _OnRondaPill extends StatelessWidget {
  const _OnRondaPill();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppColors.orange,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'On ronda',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );
}
