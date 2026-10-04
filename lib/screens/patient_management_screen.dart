import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'add_patient_screen.dart';
import 'view_patient_screen.dart';
import 'global_state.dart';
import '../widgets/app_toast.dart';

class PatientManagementScreen extends StatefulWidget {
  const PatientManagementScreen({super.key});

  @override
  State<PatientManagementScreen> createState() => _PatientManagementScreenState();
}

class _PatientManagementScreenState extends State<PatientManagementScreen> {

  Map<String, List<Map<String, dynamic>>> get _groupedPatients {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var patient in globalPatients) { 
      String date = patient['date']?.toString() ?? 'Unknown Date';
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(patient);
    }
    return grouped;
  }

  Future<void> _openPatientViewer(Map<String, dynamic> patient) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ViewPatientScreen(patient: patient)),
    );

    if (result != null) {
      setState(() {
        if (result['action'] == 'delete') {
          globalPatients.removeWhere((p) => p['id'] == patient['id']);
          AppToast.show(context, 'Record deleted.', type: ToastType.success);
        } 
        else if (result['action'] == 'update') {
          int index = globalPatients.indexWhere((p) => p['id'] == patient['id']);
          if (index != -1) globalPatients[index] = result['data'];
          AppToast.show(context, 'Record updated!', type: ToastType.success);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupedData = _groupedPatients;
    final sortedDates = groupedData.keys.toList()..sort((a, b) {
      try {
        DateTime dateA = DateFormat('MMMM d, yyyy').parse(a);
        DateTime dateB = DateFormat('MMMM d, yyyy').parse(b);
        return dateB.compareTo(dateA);
      } catch (e) {
        return 0; 
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFE5E5E5), 
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 60,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, Color(0xFF1E1E48)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  stops: [0.0, 0.6],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 15, 20, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade400),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
                ),
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 15),
                      child: Text('Patients', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w400, color: Colors.black)),
                    ),
                    
                    Expanded(
                      child: globalPatients.isEmpty 
                        ? const Center(child: Text('No patient records found.', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: sortedDates.length,
                        itemBuilder: (context, index) {
                          String date = sortedDates[index];
                          List<Map<String, dynamic>> dayPatients = groupedData[date]!;
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(date, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.bold)),
                              ),
                              
                              Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(color: Colors.grey.shade300),
                                    right: BorderSide(color: Colors.grey.shade300),
                                    bottom: BorderSide(color: Colors.grey.shade300),
                                  )
                                ),
                                child: Column(
                                  children: [
                                    for (var i = 0; i < dayPatients.length; i++) ...[
                                      InkWell(
                                        onTap: () => _openPatientViewer(dayPatients[i]), 
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(dayPatients[i]['name']?.toString() ?? 'Unnamed', style: const TextStyle(fontSize: 14, color: Colors.black87)),
                                              Text(dayPatients[i]['time']?.toString() ?? '', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (i < dayPatients.length - 1)
                                        Divider(height: 1, color: Colors.grey.shade300, indent: 15, endIndent: 15),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 15),
                            ],
                          );
                        },
                      ),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final newPatient = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AddPatientScreen()),
                          );

                          if (newPatient != null) {
                            setState(() {
                              newPatient['id'] = DateTime.now().millisecondsSinceEpoch.toString();
                              newPatient['date'] = DateFormat('MMMM d, yyyy').format(DateTime.now());
                              globalPatients.add(newPatient); 
                            });
                          }
                        },
                        icon: const Icon(Icons.add, color: Color(0xFF9C27B0), size: 20), 
                        label: const Text('Add Patient', style: TextStyle(color: Colors.black87, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5AB2E6), 
                          minimumSize: const Size(200, 45),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}