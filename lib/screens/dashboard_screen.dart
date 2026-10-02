import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Needed for date logic
import 'active_ronda_screen.dart'; 
import 'patient_management_screen.dart'; 
import 'global_state.dart'; // Imports the globalRondas list

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentNavIndex = 0;

  void _confirmStartRonda(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('START A RONDA?', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E1E48))),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx), 
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B2525)),
            child: const Text('Cancel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx); 
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ActiveRondaScreen()),
              ).then((_) {
                // Refresh Dashboard metrics instantly when returning from Active Ronda
                setState(() {}); 
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E62C8)),
            child: const Text('Start', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showMessageAdminDialog() {
    final TextEditingController messageCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.chat_bubble_outline, color: Color(0xFF2E62C8)),
            SizedBox(width: 8),
            Text('Message Admin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: TextField(
          controller: messageCtrl,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Type your message or report to the RHU Admin...',
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message sent to Admin!'), backgroundColor: Colors.green));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E62C8)),
            child: const Text('Send', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // DYNAMIC HISTORY DIALOG
  void _showRondaHistoryDialog() {
    final reversedRondas = globalRondas.reversed.toList(); // Shows newest first
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.assignment_outlined, color: Colors.orange),
            SizedBox(width: 8),
            Text('Ronda History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: reversedRondas.isEmpty 
            ? const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('No completed Rondas yet.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              )
            : ListView.separated(
            shrinkWrap: true,
            itemCount: reversedRondas.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final r = reversedRondas[index];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text('Brgy. ${r['barangay']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${r['date']} • ${r['startTime']} - ${r['endTime']}\nPatients: ${r['patientsCount']} • ${r['distance'].toStringAsFixed(1)} km'),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: Color(0xFF2E62C8)))),
        ],
      ),
    );
  }

  // DYNAMIC LAST RONDA TEXT CALCULATOR
  String _getLastRondaTime() {
    if (globalRondas.isEmpty) return 'No Rondas completed yet';
    
    DateTime lastTime = globalRondas.last['endDateTime'];
    Duration diff = DateTime.now().difference(lastTime);
    
    if (diff.inMinutes == 0) return 'Last Ronda: Just now';
    if (diff.inMinutes < 60) return 'Last Ronda: ${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return 'Last Ronda: ${diff.inHours} hours ago';
    return 'Last Ronda: ${diff.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    // CALCULATE TODAY'S DYNAMIC METRICS
    String todayStr = DateFormat('MMMM d, yyyy').format(DateTime.now());
    var todaysRondas = globalRondas.where((r) => r['date'] == todayStr).toList();
    
    int todayPatientsCount = todaysRondas.fold(0, (sum, r) => sum + (r['patientsCount'] as int));
    double todayDistanceCount = todaysRondas.fold(0.0, (sum, r) => sum + (r['distance'] as double));

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Color(0xFFD6D6D6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.65, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar Header
              Container(
                height: 65,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.white, Color(0xFF1E1E48)], begin: Alignment.centerLeft, end: Alignment.centerRight, stops: [0.35, 0.95]),
                ),
                child: Row(
                  children: [
                    Image.asset('assets/images/logo.png', height: 42, errorBuilder: (context, error, stackTrace) => const Icon(Icons.directions_bike, color: Color(0xFF1E1E48), size: 36)),
                    const SizedBox(width: 12),
                    const Text('Hello!', style: TextStyle(color: Color(0xFF1E1E48), fontSize: 22, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                      child: const CircleAvatar(radius: 20, backgroundColor: Color(0xFFCFE1FA), child: Icon(Icons.person, color: Color(0xFF1E1E48), size: 28)),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Today's Assignment
                      _buildSectionTitle("TODAY'S ASSIGNMENT"),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade400)),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(color: Color(0xFFFFB800), shape: BoxShape.circle),
                                  child: const Icon(Icons.campaign, color: Colors.white, size: 24),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Barangay: Poblacion, Bugallon', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      SizedBox(height: 3),
                                      Text('Schedule: 8:00am - 12:00pm', style: TextStyle(fontSize: 13, color: Colors.black87)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SlideToStartWidget(onSlideComplete: () => _confirmStartRonda(context)),
                            const SizedBox(height: 8),
                            // DYNAMIC LAST RONDA LABEL
                            Text(_getLastRondaTime(), style: const TextStyle(fontSize: 11, color: Colors.black54)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Section 2: DYNAMIC Today's Summary
                      _buildSectionTitle("TODAY'S SUMMARY"),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(child: _buildSummaryCard('$todayPatientsCount', 'Patients\nvisited')),
                          const SizedBox(width: 8),
                          Expanded(child: _buildSummaryCard('0', 'Appointments\n')), // Appointments not active yet
                          const SizedBox(width: 8),
                          Expanded(child: _buildSummaryCard('${todayDistanceCount.toStringAsFixed(1)} km', 'Distance\n')),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Section 3: Announcements
                      _buildSectionTitle('ANNOUNCEMENTS'),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade400)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(color: Color(0xFFFFB800), shape: BoxShape.circle),
                              child: const Icon(Icons.campaign, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Ronda Schedule Update', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  SizedBox(height: 3),
                                  Text("Tomorrow's Ronda will start at 7:30 AM instead of 8:00 AM.", style: TextStyle(fontSize: 12, color: Colors.black87)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Section 4: Action Buttons 
                      Row(
                        children: [
                          Expanded(child: _buildActionButton(icon: Icons.chat_bubble_outline, iconColor: Colors.black87, label: 'Message Admin', onTap: _showMessageAdminDialog)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildActionButton(icon: Icons.assignment_outlined, iconColor: Colors.orange.shade700, label: 'Ronda History', onTap: _showRondaHistoryDialog)),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Section 5: Feature Icons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildFeatureIcon(
                            iconWidget: const Icon(Icons.person, size: 36, color: Colors.black87),
                            label: 'Patients',
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PatientManagementScreen())).then((_) => setState(() {})),
                          ),
                          _buildFeatureIcon(
                            iconWidget: const Icon(Icons.emergency, size: 36, color: Colors.redAccent),
                            label: 'Emergency',
                            onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Emergency alert triggered!'))),
                          ),
                          _buildFeatureIcon(
                            iconWidget: const Icon(Icons.event_note, size: 36, color: Color(0xFF2E62C8)),
                            label: 'Appointments',
                            onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appointments feature coming next!'))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
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
                    IconButton(icon: Icon(Icons.home_outlined, size: 32, color: _currentNavIndex == 0 ? const Color(0xFF2E62C8) : Colors.black87), onPressed: () => setState(() => _currentNavIndex = 0)),
                    IconButton(icon: Icon(Icons.notifications_none, size: 32, color: _currentNavIndex == 1 ? const Color(0xFF2E62C8) : Colors.black87), onPressed: () => setState(() => _currentNavIndex = 1)),
                    IconButton(icon: Icon(Icons.person, size: 32, color: _currentNavIndex == 2 ? const Color(0xFF2E62C8) : Colors.black87), onPressed: () => setState(() => _currentNavIndex = 2)),
                    Container(
                      decoration: BoxDecoration(color: const Color(0xFFFFDCDA), borderRadius: BorderRadius.circular(10)),
                      child: IconButton(icon: const Icon(Icons.exit_to_app, color: Colors.redAccent, size: 28), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logging out...')))),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 0.5));
  }

  Widget _buildSummaryCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(color: const Color(0xFF75A7E9), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.1)),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required Color iconColor, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade400)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 8),
            Flexible(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureIcon({required Widget iconWidget, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Container(
            height: 65,
            width: 65,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]),
            child: Center(child: iconWidget),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// Slide-to-Start Widget tailored to fit inside the Assignment card
// ------------------------------------------------------------------
class SlideToStartWidget extends StatefulWidget {
  final VoidCallback onSlideComplete;
  const SlideToStartWidget({super.key, required this.onSlideComplete});

  @override
  State<SlideToStartWidget> createState() => _SlideToStartWidgetState();
}

class _SlideToStartWidgetState extends State<SlideToStartWidget> {
  double _dragPosition = 0.0;
  bool _isFinished = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        const double containerHeight = 46.0;
        const double thumbSize = 38.0;
        final double maxDrag = maxWidth - thumbSize - 8;

        return Container(
          height: containerHeight,
          decoration: BoxDecoration(color: const Color(0xFF2E62C8), borderRadius: BorderRadius.circular(24)),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              const Center(child: Text('SLIDE TO START RONDA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5))),
              AnimatedPositioned(
                duration: _isFinished || _dragPosition == 0.0 ? const Duration(milliseconds: 200) : Duration.zero,
                left: 4 + _dragPosition,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _dragPosition += details.delta.dx;
                      if (_dragPosition < 0) _dragPosition = 0;
                      if (_dragPosition > maxDrag) _dragPosition = maxDrag;
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (_dragPosition >= maxDrag * 0.8) {
                      setState(() { _dragPosition = maxDrag; _isFinished = true; });
                      widget.onSlideComplete();
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (mounted) setState(() { _dragPosition = 0.0; _isFinished = false; });
                      });
                    } else {
                      setState(() => _dragPosition = 0.0);
                    }
                  },
                  child: Container(
                    height: thumbSize,
                    width: thumbSize,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.directions_bike, color: Color(0xFF2E62C8), size: 20),
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