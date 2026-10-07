import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'menu.dart';
import 'sos_button.dart';
import 'emergency_request_screen.dart';
import 'profile.dart';
import '../../core/auth_service.dart';
import 'medical_history_screen.dart';
import 'visit_record.dart';


class ResidentDashboardScreen extends StatefulWidget {
  final AppUser currentUser;

  const ResidentDashboardScreen({super.key, required this.currentUser});

  @override
  State<ResidentDashboardScreen> createState() =>
      _ResidentDashboardScreenState();
}

class _ResidentDashboardScreenState extends State<ResidentDashboardScreen> {
  int _tab = 0;

     String get _patientName =>
      (widget.currentUser.name ?? '').toUpperCase();
  String get _barangay =>
      (widget.currentUser.barangay ?? '').toUpperCase();


  void _soon(String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label coming soon')));
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
            const _Placeholder('History'),
            const _Placeholder('Safety'),
            const _Placeholder('Settings'),
          ],
        ),
      ),
      bottomNavigationBar: _bottomNav(),
    );
  }

  Widget _home() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        children: [
                    _header(),
          const SizedBox(height: 20),
          MenuCard(
            icon: Icons.medical_services_rounded,
            title: 'View Medical History',
            subtitle: 'Review your health records',
            accent: AppColors.blue,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MedicalHistoryScreen(visits: sampleVisits),
              ),
            ),
          ),
          const SizedBox(height: 14),
          MenuCard(
            icon: Icons.calendar_month_rounded,
            title: 'Appointment',
            subtitle: 'Request an appointment',
            accent: AppColors.red,
            onTap: () => _soon('Appointments'),
          ),
          const SizedBox(height: 14),
          MenuCard(
            icon: Icons.local_hospital_rounded,
            title: 'Health Services',
            subtitle: 'Explore available health services',
            accent: AppColors.orange,
            onTap: () => _soon('Health services'),
          ),
          const SizedBox(height: 28),
          SosButton(
            onActivated: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const EmergencyRequestScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
                Image.asset(
          'assets/images/logo.png',
          height: 44,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.pedal_bike_rounded,
            color: AppColors.red,
            size: 36,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _patientName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                _barangay,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          customBorder: const CircleBorder(),
                    onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
               builder: (_) => ProfileScreen(
                name: widget.currentUser.name ?? '',
                phone: widget.currentUser.mobile ?? '',
              ),
            ),
          ),
          child: Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.redSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_outline_rounded,
                color: AppColors.red, size: 22),
          ),
        ),
      ],
    );
  }

  
  Widget _bottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 0,
        selectedItemColor: AppColors.red,
        unselectedItemColor: AppColors.textMuted,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded), label: 'HOME'),
          BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded), label: 'HISTORY'),
          BottomNavigationBarItem(
              icon: Icon(Icons.shield_outlined), label: 'SAFETY'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined), label: 'SETTINGS'),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String title;
  const _Placeholder(this.title);

  @override
  Widget build(BuildContext context) => Center(
        child: Text(title,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted)),
      );
}