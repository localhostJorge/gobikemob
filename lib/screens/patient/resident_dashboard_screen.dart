import 'package:flutter/material.dart';

import '../../core/app_navigator.dart' show vibratePhone;
import '../../core/appointments.dart';
import '../../core/auth_service.dart';
import '../../core/resident_sos.dart';
import '../../core/resident_visits.dart';
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
import 'settings_screen.dart';
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

class _ResidentDashboardScreenState extends State<ResidentDashboardScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    PatientStore.instance.load();
    ResidentVisits.instance.load();
    ResidentAppointments.instance.load(); // shown in History
    ResidentSos.instance.onStatusChanged = _onSosChanged;
  }

  @override
  void dispose() {
    if (ResidentSos.instance.onStatusChanged == _onSosChanged) {
      ResidentSos.instance.onStatusChanged = null;
    }
    super.dispose();
  }

  /// The admin answered the SOS while the app is open: vibrate and say so.
  void _onSosChanged(SosEntry sos) {
    if (sos.status != 'responding' && sos.status != 'resolved') return;
    if (PatientStore.instance.toggle('vibration')) vibratePhone();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text(
            sos.status == 'responding'
                ? 'Someone is Responding to your SOS.'
                : 'Your SOS request was resolved.',
          ),
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: IndexedStack(
          index: _tab,
          children: [
            _home(),
            const HistoryTab(),
            SafetyTab(active: _tab == 2),
            const SettingsTab(),
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
        padding: const EdgeInsets.fromLTRB(Sp.gutter, Sp.lg, Sp.gutter, Sp.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            const SizedBox(height: Sp.xl + Sp.sm),
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
            const SizedBox(height: Sp.xl + Sp.sm),
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
                        const Icon(
                          Icons.place_outlined,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: Sp.xs),
                        Flexible(
                          child: Text(
                            place,
                            overflow: TextOverflow.ellipsis,
                            style: T.secondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Sp.md),
            Semantics(
              button: true,
              label: 'Your profile',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ProfileScreen(currentUser: widget.currentUser),
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: ProfileAvatar(radius: 22),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _bottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 0,
        selectedItemColor: AppColors.redText,
        unselectedItemColor: AppColors.textMuted,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        selectedLabelStyle: T.meta.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: T.meta,
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
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
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
                color: AppColors.orangeText,
                title: 'Home visit',
                subtitle: visit == null
                    ? 'Ask a GoBiker to check on you at home'
                    : '${visit.statusLabel} · ${formatDate(visit.preferredDate)}',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AppointmentScreen()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
