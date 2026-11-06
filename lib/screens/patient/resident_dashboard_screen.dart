import 'package:flutter/material.dart';

import '../../core/app_navigator.dart' show vibratePhone;
import '../../core/appointments.dart';
import '../../core/auth_service.dart';
import '../../core/feedback_prompt.dart';
import '../../core/presence_service.dart';
import '../../core/resident_sos.dart';
import '../../core/resident_visits.dart';
import '../live_map_screen.dart';
import '../../widgets/bottom_gap.dart';
import 'app_colors.dart';
import 'appointment_screen.dart';
import 'emergency_request_screen.dart';
import 'history_screen.dart';
import 'medical_history_screen.dart';
import 'mobile_number_prompt.dart';
import 'patient_store.dart';
import 'profile.dart';
import 'profile_avatar.dart';
import 'safety_tab.dart';
import 'skeletons.dart';
import 'sos_button.dart';
import 'ui_kit.dart';
import 'visit_record.dart' show formatDate;
import 'visit_request_screen.dart';

class ResidentDashboardScreen extends StatefulWidget {
  final AppUser currentUser;

  const ResidentDashboardScreen({super.key, required this.currentUser});

  @override
  State<ResidentDashboardScreen> createState() =>
      _ResidentDashboardScreenState();
}

class _ResidentDashboardScreenState extends State<ResidentDashboardScreen>
    with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _loadVisits();
    ResidentVisits.instance.load();
    ResidentSos.instance.onStatusChanged = _onSosChanged;
    WidgetsBinding.instance.addObserver(this);
    PresenceService.instance.start(); // on the GoBikers' live map while open
    // A GoBiker resolved an SOS or did a check-up: ask for a rating.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => FeedbackPrompt.instance.check(),
    );
  }

  /// The saved settings first, then the visit requests (shown in History). Whatever the
  /// GoBikers had already answered before this version is taken as seen, so the History badge
  /// counts only what is new from now on.
  Future<void> _loadVisits() async {
    await PatientStore.instance.load();
    await ResidentAppointments.instance.load();
    if (ResidentAppointments.instance.loaded) {
      await PatientStore.instance.baselineVisits(
        ResidentAppointments.instance.appointments,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) FeedbackPrompt.instance.check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (ResidentSos.instance.onStatusChanged == _onSosChanged) {
      ResidentSos.instance.onStatusChanged = null;
    }
    super.dispose();
  }

  /// The admin answered the SOS while the app is open: vibrate and say so.
  void _onSosChanged(SosEntry sos) {
    if (sos.status != 'responding' && sos.status != 'resolved') return;
    if (sos.status == 'resolved') FeedbackPrompt.instance.check();
    if (PatientStore.instance.toggle('vibration')) vibratePhone();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text(switch (sos.status) {
            // Only name a responder once the admin has actually sent one.
            'responding' when sos.responderName != null =>
              '${sos.responderName} is responding to your SOS.',
            'responding' => 'The Go Bike admin is handling your SOS.',
            _ => 'Your SOS request was resolved.',
          }),
        ),
      );
  }

  String get _firstName {
    final name = (PatientStore.instance.fullName ?? widget.currentUser.name)
        .trim();
    return name.isEmpty ? 'there' : name.split(RegExp(r'\s+')).first;
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String? get _place {
    final b = (PatientStore.instance.barangay ?? widget.currentUser.barangay)
        ?.trim();
    return (b == null || b.isEmpty) ? null : '$b, Bugallon';
  }

  Future<void> _refreshHome() => Future.wait([
    ResidentVisits.instance.load(),
    ResidentAppointments.instance.load(),
    ResidentSos.instance.load(),
  ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pal.background,
      body: SafeArea(
        child: IndexedStack(
          index: _tab,
          children: [
            _home(),
            const HistoryTab(),
            SafetyTab(active: _tab == 2),
            ProfileTab(currentUser: widget.currentUser),
          ],
        ),
      ),
      bottomNavigationBar: _bottomNav(),
    );
  }

  Widget _home() {
    return RefreshIndicator(
      color: AppColors.red,
      onRefresh: _refreshHome,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(Sp.gutter, Sp.md, Sp.gutter, Sp.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            const SizedBox(height: Sp.lg),
            // The one thing that must be easy to find: first, and biggest.
            Center(
              child: ListenableBuilder(
                listenable: PatientStore.instance,
                builder: (context, _) {
                  final hold = PatientStore.instance.sosHoldSeconds;
                  return SosButton(
                    // New key so the button restarts when the hold time changes.
                    key: ValueKey(hold),
                    holdDuration: Duration(seconds: hold),
                    onActivated: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EmergencyRequestScreen(),
                      ),
                    ),
                  );
                },
              ),
            ),
            // An open SOS shows right here, under the button.
            HomeSosStatus(active: _tab == 0),
            const SizedBox(height: Sp.xl),
            const MobileNumberPrompt(),
            const SectionHeader('Your health'),
            const _HealthList(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return ListenableBuilder(
      listenable: PatientStore.instance,
      builder: (context, _) {
        final place = _place;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$_greeting, $_firstName', style: T.title),
                  if (place != null) ...[
                    const SizedBox(height: Sp.xs),
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 16,
                          color: context.pal.muted,
                        ),
                        const SizedBox(width: Sp.xs),
                        Flexible(
                          child: Text(
                            place,
                            overflow: TextOverflow.ellipsis,
                            style: T.secondary.muted(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _bottomNav() {
    // Listens itself, so the badge follows the answers as they arrive.
    return ListenableBuilder(
      listenable: Listenable.merge([
        ResidentAppointments.instance,
        PatientStore.instance,
      ]),
      builder: (context, _) {
        final updates = PatientStore.instance.unseenVisitCount(
          ResidentAppointments.instance.appointments,
        );
        return Container(
          // Room for the phone's own navigation area and its home-gesture strip, so the
          // tabs sit above it instead of down in it (and a tap on one is not a swipe home).
          padding: EdgeInsets.only(bottom: bottomGap(context) + 4),
          decoration: BoxDecoration(
            color: context.pal.card,
            border: Border(top: BorderSide(color: context.pal.line)),
          ),
          // The gap is already added above; the bar must not add its own as well.
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: BottomNavigationBar(
              currentIndex: _tab,
              onTap: (i) => setState(() => _tab = i),
              type: BottomNavigationBarType.fixed,
              backgroundColor: context.pal.card,
              elevation: 0,
              selectedItemColor: context.pal.redText,
              unselectedItemColor: context.pal.muted,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              selectedLabelStyle: T.meta
                  .muted(context)
                  .copyWith(fontWeight: FontWeight.w700),
              unselectedLabelStyle: T.meta.muted(context),
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: _historyIcon(updates),
                  tooltip: updates == 0
                      ? 'History'
                      : 'History, $updates new ${updates == 1 ? 'update' : 'updates'}',
                  label: 'History',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.shield_outlined),
                  activeIcon: Icon(Icons.shield_rounded),
                  label: 'Safety',
                ),
                const BottomNavigationBarItem(
                  icon: NavProfileIcon(selected: false),
                  activeIcon: NavProfileIcon(selected: true),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The History icon, with a count of the answers the person has not opened yet.
  Widget _historyIcon(int updates) {
    const icon = Icon(Icons.history_rounded);
    if (updates == 0) return icon;
    return Badge(
      label: Text('$updates'),
      backgroundColor: AppColors.redButton,
      textColor: Colors.white,
      child: icon,
    );
  }
}

/// The newest declined request that still needs the person's attention on the Home screen:
/// not hidden, not followed up (asking someone else hides it), and from the last two weeks.
Appointment? _declinedForHome(List<Appointment> all) {
  final cutoff = DateTime.now().subtract(const Duration(days: 14));
  final declined =
      all
          .where(
            (a) =>
                a.status == 'declined' &&
                !PatientStore.instance.isDeclineHidden(a.id) &&
                a.changedAt.isAfter(cutoff),
          )
          .toList()
        ..sort((a, b) => b.changedAt.compareTo(a.changedAt));
  return declined.firstOrNull;
}

/// Medical history and home visits as one plain list, each row saying what
/// is actually there (last check-up, visit status) instead of a slogan.
class _HealthList extends StatelessWidget {
  const _HealthList();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ResidentVisits.instance,
        ResidentAppointments.instance,
        PatientStore.instance, // which declined requests were hidden
      ]),
      builder: (context, _) {
        final visits = ResidentVisits.instance;
        final appointments = ResidentAppointments.instance;
        // Skeleton only until both have answered once; refreshes keep the rows.
        final loading =
            (!visits.loaded && visits.loading) ||
            (!appointments.loaded && appointments.loading);

        final last = visits.visits.isEmpty
            ? null
            : visits.visits.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
        final declined = _declinedForHome(appointments.appointments);

        return LoadSwitcher(
          loading: loading,
          skeleton: const HealthListSkeleton(),
          child: CardGroup(
            dividerIndent: 52,
            children: [
              NavRow(
                icon: Icons.favorite_border_rounded,
                color: AppColors.blue,
                title: 'Medical history',
                subtitle: last == null
                    ? 'No check-ups yet'
                    : 'Last check-up ${formatDate(last.date)} · '
                          'BP ${last.systolic}/${last.diastolic}',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MedicalHistoryScreen(),
                  ),
                ),
              ),
              NavRow(
                icon: Icons.home_outlined,
                color: context.pal.orangeText,
                title: 'Home visit',
                // Always a new request. How the ones already sent stand is in History.
                subtitle: 'Ask a GoBiker to check on you at home',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AppointmentScreen()),
                ),
              ),
              NavRow(
                icon: Icons.map_outlined,
                color: AppColors.blue,
                title: 'Map',
                subtitle: 'View live map',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LiveMapScreen()),
                ),
              ),
              // Requests still open (waiting, or accepted and not done yet). Once answered for
              // good they leave Home and stay in History.
              for (final a in appointments.open)
                NavRow(
                  icon: Icons.home_outlined,
                  color: context.pal.orangeText,
                  title: 'Home visit request',
                  subtitle:
                      '${a.gobikerName ?? 'A GoBiker'} · '
                      '${formatDate(a.preferredDate)} · '
                      '${a.status == 'accepted' ? 'Accepted' : 'Waiting for the GoBiker to accept'}',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VisitRequestScreen(appointmentId: a.id),
                    ),
                  ),
                ),
              // A GoBiker said no: the details show their message and other GoBikers to ask.
              if (declined != null)
                NavRow(
                  icon: Icons.event_busy_outlined,
                  color: context.pal.redText,
                  title: 'Visit declined',
                  subtitle:
                      '${declined.gobikerName ?? 'A GoBiker'} · '
                      '${formatDate(declined.preferredDate)}. '
                      'Tap to ask someone else.',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          VisitRequestScreen(appointmentId: declined.id),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
