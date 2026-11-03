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
    PatientStore.instance.load();
    ResidentVisits.instance.load();
    ResidentAppointments.instance.load(); // shown in History
    ResidentSos.instance.onStatusChanged = _onSosChanged;
    WidgetsBinding.instance.addObserver(this);
    PresenceService.instance.start(); // on the GoBikers' live map while open
    // A GoBiker resolved an SOS or did a check-up: ask for a rating.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => FeedbackPrompt.instance.check(),
    );
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
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shield_outlined),
              activeIcon: Icon(Icons.shield_rounded),
              label: 'Safety',
            ),
            BottomNavigationBarItem(
              icon: NavProfileIcon(selected: false),
              activeIcon: NavProfileIcon(selected: true),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
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
        final visit = appointments.current;

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
                subtitle: visit == null
                    ? 'Ask a GoBiker to check on you at home'
                    : '${visit.statusLabel} · ${formatDate(visit.preferredDate)}',
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
            ],
          ),
        );
      },
    );
  }
}
