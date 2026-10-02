import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import 'add_patient_screen.dart'; 
import 'view_patient_screen.dart'; 
import 'global_state.dart'; 

class ActiveRondaScreen extends StatefulWidget {
  const ActiveRondaScreen({super.key});

  @override
  State<ActiveRondaScreen> createState() => _ActiveRondaScreenState();
}

class _ActiveRondaScreenState extends State<ActiveRondaScreen> {
  String? selectedBarangay; 
  int _patientsVisited = 0;
  
  Timer? _timer;
  int _secondsElapsed = 0; 
  String _startTime = '--:--'; 

  final List<Map<String, dynamic>> _todayPatients = [];

  final List<String> barangays = [
    'Angarian', 'Asinan', 'Bacabac', 'Bañaga', 'Bolaoen', 'Buenlag',
    'Cabayaoasan', 'Cayanga', 'Gueset', 'Hacienda', 'Laguit Centro',
    'Laguit Padilla', 'Magtaking', 'Pangascasan', 'Pantal', 'Poblacion',
    'Polong', 'Portic', 'Salasa', 'Salomague Norte', 'Salomague Sur',
    'Samat', 'San Francisco', 'Umanday'
  ];

  @override
  void initState() {
    super.initState();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _secondsElapsed++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formattedTime {
    int hours = _secondsElapsed ~/ 3600;
    int minutes = (_secondsElapsed % 3600) ~/ 60;
    int seconds = _secondsElapsed % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<bool> _confirmEndRonda() async {
    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Stop Ronda?', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to stop the ronda?', textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B2525)),
            child: const Text('Cancel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2962FF)),
            child: const Text('Stop', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldEnd == true) {
      _timer?.cancel();
      
      // Save the completed shift to the Global Dashboard History
      if (selectedBarangay != null) {
        globalRondas.add({
          'barangay': selectedBarangay,
          'date': DateFormat('MMMM d, yyyy').format(DateTime.now()),
          'startTime': _startTime,
          'endTime': DateFormat('hh:mm a').format(DateTime.now()),
          'endDateTime': DateTime.now(), // Used to calculate "Minutes ago"
          'patientsCount': _patientsVisited,
          'distance': 1.5 + (_patientsVisited * 0.3), // Simulates distance dynamically
        });
      }
      
      return true; 
    }
    return false; 
  }

  // Opens the full-screen editor
  Future<void> _openPatientViewer(int index) async {
    final patient = _todayPatients[index];
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ViewPatientScreen(patient: patient)),
    );

    if (result != null) {
      setState(() {
        if (result['action'] == 'delete') {
          // Remove from local and global lists
          _todayPatients.removeWhere((p) => p['id'] == patient['id']);
          globalPatients.removeWhere((p) => p['id'] == patient['id']);
          _patientsVisited--;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Record deleted.')));
        } 
        else if (result['action'] == 'update') {
          // Update local and global lists
          _todayPatients[index] = result['data'];
          int globalIndex = globalPatients.indexWhere((p) => p['id'] == patient['id']);
          if (globalIndex != -1) globalPatients[globalIndex] = result['data'];
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Record updated!'), backgroundColor: Colors.green));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmEndRonda,
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1E48), 
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: selectedBarangay == null ? Colors.redAccent : Colors.grey.shade400, width: 2), 
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      hint: const Text('CHOOSE BARANGAY TO START', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.0)),
                      value: selectedBarangay,
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF9E2A2B), size: 40), 
                      style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedBarangay = newValue;
                          if (_timer == null || !_timer!.isActive) {
                            _startTime = DateFormat('hh:mm a').format(DateTime.now());
                            _startTimer();
                          }
                        });
                      },
                      items: barangays.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value, 
                          child: Text(value.toUpperCase())
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 5.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('TODAY\'S PATIENT LOG', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
              ),

              Expanded(
                child: _todayPatients.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_ind_outlined, size: 50, color: Colors.white.withOpacity(0.5)),
                            const SizedBox(height: 10),
                            Text(
                              selectedBarangay == null 
                                  ? 'Select a Barangay above\nto begin your Ronda.'
                                  : 'No patients logged yet.\nClick "Add Patient" to start.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        itemCount: _todayPatients.length,
                        itemBuilder: (context, index) {
                          final patient = _todayPatients[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => _openPatientViewer(index), 
                              child: Padding(
                                padding: const EdgeInsets.all(15.0),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 75,
                                      child: Text(patient['time'], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2962FF), fontSize: 13)),
                                    ),
                                    Container(height: 20, width: 1, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 10)),
                                    Expanded(
                                      child: Text(patient['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis),
                                    ),
                                    const Icon(Icons.chevron_right, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),

              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                ),
                child: Column(
                  children: [
                    Text('Started at: $_startTime', style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 15),

                    Row(
                      children: [
                        Expanded(child: _buildMetricCard('Duration', _formattedTime, Icons.timer, Colors.red)),
                        const SizedBox(width: 15),
                        Expanded(child: _buildMetricCard('Patients Visited', '$_patientsVisited', Icons.person_add_alt_1, const Color(0xFF2962FF))),
                      ],
                    ),
                    const SizedBox(height: 25),
                    
                    ElevatedButton.icon(
                      onPressed: selectedBarangay == null ? null : () async {
                        final newPatient = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AddPatientScreen()),
                        );

                        if (newPatient != null) {
                          setState(() {
                            newPatient['id'] = DateTime.now().millisecondsSinceEpoch.toString();
                            newPatient['date'] = DateFormat('MMMM d, yyyy').format(DateTime.now());

                            _todayPatients.add(newPatient); 
                            globalPatients.add(newPatient); 
                            _patientsVisited++; 
                          });
                        }
                      },
                      icon: Icon(Icons.add, color: selectedBarangay == null ? Colors.grey.shade400 : Colors.white),
                      label: Text('Add Patient', style: TextStyle(color: selectedBarangay == null ? Colors.grey.shade500 : Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedBarangay == null ? Colors.grey.shade300 : const Color(0xFF2962FF),
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      onPressed: () async {
                        bool shouldExit = await _confirmEndRonda();
                        if (shouldExit && mounted) {
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.stop_circle, color: Colors.white),
                      label: const Text('END RONDA', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
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

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}