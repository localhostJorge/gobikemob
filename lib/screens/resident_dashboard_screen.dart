import 'package:flutter/material.dart';
import 'login_screen.dart';

class ResidentDashboardScreen extends StatefulWidget {
  const ResidentDashboardScreen({super.key});

  @override
  State<ResidentDashboardScreen> createState() => _ResidentDashboardScreenState();
}

class _ResidentDashboardScreenState extends State<ResidentDashboardScreen> {
  int _currentNavIndex = 0;

  // Emergency SOS Trigger
  void _triggerSOS() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
            SizedBox(width: 10),
            Text('EMERGENCY SOS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          ],
        ),
        content: const Text(
          'This will alert the RHU and the nearest GoBiker that you need immediate medical assistance at your registered address.\n\nProceed?',
          style: TextStyle(fontSize: 15),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade300, elevation: 0),
            child: const Text('Cancel', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('SOS Alert Sent! Help is being dispatched.'),
                  backgroundColor: Colors.redAccent,
                  duration: Duration(seconds: 4),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('SEND SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Request Check-up Trigger
  void _requestVisit() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Request Check-up', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Would you like to schedule a standard visit for the next time a GoBiker is in your area?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Visit requested successfully!'), backgroundColor: Colors.green),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E62C8)),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5E5E5),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar Header
            Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, Color(0xFF1E1E48)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  stops: [0.3, 1.0],
                ),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 22,
                    backgroundColor: Color(0xFFCFE1FA),
                    child: Icon(Icons.person, color: Color(0xFF1E1E48), size: 28),
                  ),
                  const SizedBox(width: 15),
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hello, Resident!', style: TextStyle(color: Color(0xFF1E1E48), fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Brgy. Poblacion', style: TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const Spacer(),
                  Image.asset('assets/images/logo.png', height: 35, errorBuilder: (c, e, s) => const Icon(Icons.directions_bike, color: Colors.white, size: 30)),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Live Ronda Tracker
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            height: 12,
                            width: 12,
                            decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'A GoBiker is currently active in your barangay.',
                              style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),

                    // 2. The Lifeline (SOS Button)
                    InkWell(
                      onTap: _triggerSOS,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8)),
                          ],
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.emergency_share, color: Colors.white, size: 50),
                            SizedBox(height: 10),
                            Text('EMERGENCY SOS', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                            SizedBox(height: 5),
                            Text('Tap to request immediate medical help', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    // 3. Quick Actions (Request Visit & Health Records)
                    Row(
                      children: [
                        Expanded(
                          child: _buildResidentActionCard(
                            title: 'Request\nCheck-up',
                            icon: Icons.calendar_month,
                            color: const Color(0xFF2E62C8),
                            onTap: _requestVisit,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _buildResidentActionCard(
                            title: 'My Health\nPassport',
                            icon: Icons.monitor_heart_outlined,
                            color: const Color(0xFF009688),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening Health Records...')));
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // 4. Community Announcements
                    const Text('COMMUNITY ANNOUNCEMENTS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 0.5)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.orange.shade100, shape: BoxShape.circle),
                            child: const Icon(Icons.campaign, color: Colors.orange, size: 28),
                          ),
                          const SizedBox(width: 15),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Free Flu Vaccines', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                SizedBox(height: 4),
                                Text('Available at the RHU main center this Friday from 8 AM to 3 PM for all residents.', style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.3)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Navigation Bar
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))]),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(icon: Icon(Icons.home, size: 32, color: _currentNavIndex == 0 ? const Color(0xFF2E62C8) : Colors.black87), onPressed: () => setState(() => _currentNavIndex = 0)),
                  IconButton(icon: Icon(Icons.history, size: 32, color: _currentNavIndex == 1 ? const Color(0xFF2E62C8) : Colors.black87), onPressed: () => setState(() => _currentNavIndex = 1)),
                  IconButton(icon: Icon(Icons.person_outline, size: 32, color: _currentNavIndex == 2 ? const Color(0xFF2E62C8) : Colors.black87), onPressed: () => setState(() => _currentNavIndex = 2)),
                  Container(
                    decoration: BoxDecoration(color: const Color(0xFFFFDCDA), borderRadius: BorderRadius.circular(10)),
                    child: IconButton(
                      icon: const Icon(Icons.exit_to_app, color: Colors.redAccent, size: 28), 
                      onPressed: () {
                        // Logout logic
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper Widget for the square action buttons
  Widget _buildResidentActionCard({required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 3))],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}