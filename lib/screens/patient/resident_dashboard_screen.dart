import 'package:flutter/material.dart';

import '../../core/appointments.dart';
import '../../core/app_navigator.dart' show vibratePhone;
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
import 'sos_button.dart';
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const SizedBox(height: 28),
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
          const SizedBox(height: 28),
          const MobileNumberPrompt(),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(
              'Your health',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
          ),
          const _HealthList(),
        ],
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
                  Text(
                    '$_greeting, $_firstName',
                    style: const TextStyle(
                      fontSize: 24,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  if (place != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            place,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
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
        border: Border(top: BorderSide(color: Color(0xFFECE7E7))),
      ),
      child: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 0,
        selectedItemColor: AppColors.red,
        unselectedItemColor: AppColors.textMuted,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            activeIcon: Icon(Icons.history_rounded),
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
        final visits = ResidentVisits.instance.visits;
        final last = visits.isEmpty
            ? null
            : visits.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
        final visit = ResidentAppointments.instance.current;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFECE7E7)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _HealthRow(
                icon: Icons.favorite_border_rounded,
                color: AppColors.blue,
                title: 'Medical history',
                detail: last == null
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
              const Divider(height: 1, indent: 52, color: Color(0xFFF0ECEC)),
              _HealthRow(
                icon: Icons.home_outlined,
                color: AppColors.orange,
                title: 'Home visit',
                detail: visit == null
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

class _HealthRow extends StatelessWidget {
  const _HealthRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
