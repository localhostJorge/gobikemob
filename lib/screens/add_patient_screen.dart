import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Run: flutter pub add intl


class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers to capture user input
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _contactCtrl = TextEditingController();
  final TextEditingController _ageCtrl = TextEditingController();
  
  final TextEditingController _sysCtrl = TextEditingController();
  final TextEditingController _diaCtrl = TextEditingController();
  final TextEditingController _pulseCtrl = TextEditingController();
  final TextEditingController _respCtrl = TextEditingController();
  final TextEditingController _tempCtrl = TextEditingController();
  final TextEditingController _heightCtrl = TextEditingController();
  final TextEditingController _weightCtrl = TextEditingController();

  void _showConfirmationDialog() {
    // Only proceed if the required fields are filled
    if (_formKey.currentState!.validate()) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Are you sure you\nwant to submit?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 25),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context); // Close dialog
                            _submitPatient(); // Process data and go back to Dashboard
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2962FF), // Blue
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Submit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context), // Just close dialog
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B2525), // Dark Red
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Cancel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      );
    }
  }

  void _submitPatient() {
    String currentTime = DateFormat('hh:mm a').format(DateTime.now());

    Map<String, dynamic> newPatientData = {
      'time': currentTime,
      'name': _nameCtrl.text,
      'address': _addressCtrl.text,
      'contact': _contactCtrl.text,
      'age': _ageCtrl.text,
      'sys': _sysCtrl.text,
      'dia': _diaCtrl.text,
      'pulse': _pulseCtrl.text,
      'resp': _respCtrl.text,
      'temp': _tempCtrl.text,
      'height': _heightCtrl.text,
      'weight': _weightCtrl.text,
      // STATUS AND COLOR HAVE BEEN COMPLETELY REMOVED
    };

    Navigator.pop(context, newPatientData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // The silver/grey gradient background
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Color(0xFFBDBDBD)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Dark Blue Header Bar
              Container(
                height: 60,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white, Color(0xFF1E1E48)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: [0.0, 0.4],
                  )
                ),
              ),
              
              // App Bar / Title Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(backgroundColor: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'Patient Information',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 48), // Balance for centering
                  ],
                ),
              ),

              // Scrollable Form
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildLabelAboveField('Full Name', _nameCtrl),
                        const SizedBox(height: 15),
                        _buildLabelAboveField('Address', _addressCtrl),
                        const SizedBox(height: 15),
                        _buildLabelAboveField('Contact Number', _contactCtrl, isNumber: true),
                        const SizedBox(height: 15),
                        _buildLabelAboveField('Age', _ageCtrl, isNumber: true),
                        
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 25),
                          child: Text('Patient Vitals', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),

                        // Blood Pressure Split Field
                        _buildRequiredLabel('Blood Pressure'),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Expanded(child: _buildTextField(_sysCtrl, hint: 'Systolic', isNumber: true)),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Text('/', style: TextStyle(fontSize: 28, color: Colors.black54, fontWeight: FontWeight.w300)),
                            ),
                            Expanded(child: _buildTextField(_diaCtrl, hint: 'Diastolic', isNumber: true)),
                          ],
                        ),
                        const SizedBox(height: 15),

                        // Inside-Label Fields
                        _buildInsideHintField('Pulse', _pulseCtrl),
                        const SizedBox(height: 15),
                        _buildInsideHintField('Respiration', _respCtrl),
                        const SizedBox(height: 15),
                        _buildInsideHintField('Temperature', _tempCtrl),
                        const SizedBox(height: 15),
                        _buildInsideHintField('Height (cm)', _heightCtrl),
                        const SizedBox(height: 15),
                        _buildInsideHintField('Weight (kg)', _weightCtrl),
                        const SizedBox(height: 35),

                        // Submit Button
                        ElevatedButton(
                          onPressed: _showConfirmationDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2962FF),
                            minimumSize: const Size(double.infinity, 55),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text('Submit', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets for Form Design ---

  Widget _buildRequiredLabel(String text) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.black87, fontSize: 14),
        children: const [
          TextSpan(text: '  *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLabelAboveField(String label, TextEditingController controller, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRequiredLabel(label),
        const SizedBox(height: 5),
        _buildTextField(controller, isNumber: isNumber),
      ],
    );
  }

  Widget _buildInsideHintField(String hint, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      validator: (value) => value!.isEmpty ? '' : null,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        suffixIcon: const Padding(
          padding: EdgeInsets.only(top: 15, right: 20),
          child: Text('*', style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade400)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade400)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2962FF), width: 2)),
        errorStyle: const TextStyle(height: 0), // Hides default ugly error text, relies on red border
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, {String? hint, bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      validator: (value) => value!.isEmpty ? '' : null,
      textAlign: hint != null ? TextAlign.center : TextAlign.start,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade400)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade400)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2962FF), width: 2)),
        errorStyle: const TextStyle(height: 0),
      ),
    );
  }
}