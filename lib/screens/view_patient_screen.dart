import 'package:flutter/material.dart';

class ViewPatientScreen extends StatefulWidget {
  final Map<String, dynamic> patient;
  const ViewPatientScreen({super.key, required this.patient});

  @override
  State<ViewPatientScreen> createState() => _ViewPatientScreenState();
}

class _ViewPatientScreenState extends State<ViewPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false; 

  late TextEditingController _nameCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _contactCtrl;
  late TextEditingController _ageCtrl;
  late TextEditingController _sysCtrl;
  late TextEditingController _diaCtrl;
  late TextEditingController _pulseCtrl;
  late TextEditingController _respCtrl;
  late TextEditingController _tempCtrl;
  late TextEditingController _heightCtrl;
  late TextEditingController _weightCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.patient['name']?.toString() ?? '');
    _addressCtrl = TextEditingController(text: widget.patient['address']?.toString() ?? '');
    _contactCtrl = TextEditingController(text: widget.patient['contact']?.toString() ?? '');
    _ageCtrl = TextEditingController(text: widget.patient['age']?.toString() ?? '');
    _sysCtrl = TextEditingController(text: widget.patient['sys']?.toString() ?? '');
    _diaCtrl = TextEditingController(text: widget.patient['dia']?.toString() ?? '');
    _pulseCtrl = TextEditingController(text: widget.patient['pulse']?.toString() ?? '');
    _respCtrl = TextEditingController(text: widget.patient['resp']?.toString() ?? '');
    _tempCtrl = TextEditingController(text: widget.patient['temp']?.toString() ?? '');
    _heightCtrl = TextEditingController(text: widget.patient['height']?.toString() ?? '');
    _weightCtrl = TextEditingController(text: widget.patient['weight']?.toString() ?? '');
  }

  void _submitChanges() {
    if (_isEditing && _formKey.currentState!.validate()) {
      Map<String, dynamic> updatedData = {
        'id': widget.patient['id'],
        'date': widget.patient['date'],
        'time': widget.patient['time'],
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
      };
      Navigator.pop(context, {'action': 'update', 'data': updatedData});
    } else if (!_isEditing) {
      Navigator.pop(context); 
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Record?'),
        content: const Text('Are you sure you want to permanently delete this patient record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, {'action': 'delete', 'data': widget.patient});
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: _confirmDelete,
                      style: IconButton.styleFrom(backgroundColor: Colors.white),
                    ),
                  ],
                ),
              ),

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

                        // Blood Pressure Section
                        const Text('Blood Pressure', style: TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold)),
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

                        // Now using explicit labels above each vital field
                        _buildLabelAboveField('Pulse', _pulseCtrl, isNumber: true),
                        const SizedBox(height: 15),
                        _buildLabelAboveField('Respiration', _respCtrl, isNumber: true),
                        const SizedBox(height: 15),
                        _buildLabelAboveField('Temperature', _tempCtrl, isNumber: true),
                        const SizedBox(height: 15),
                        _buildLabelAboveField('Height (cm)', _heightCtrl, isNumber: true),
                        const SizedBox(height: 15),
                        _buildLabelAboveField('Weight (kg)', _weightCtrl, isNumber: true),
                        const SizedBox(height: 35),

                        // Green Edit & Blue Submit Buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() => _isEditing = !_isEditing);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1DA634), 
                                  minimumSize: const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                                ),
                                child: Text(_isEditing ? 'Editing...' : 'Edit', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _submitChanges,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2962FF), 
                                  minimumSize: const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                                ),
                                child: const Text('Submit', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
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

  // Unified Widget for fields with labels above them
  Widget _buildLabelAboveField(String label, TextEditingController controller, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        _buildTextField(controller, isNumber: isNumber),
      ],
    );
  }

  // Updated text field that uses Floating Labels
  Widget _buildTextField(TextEditingController controller, {String? hint, bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      readOnly: !_isEditing,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      textAlign: hint != null ? TextAlign.center : TextAlign.start,
      decoration: InputDecoration(
        labelText: hint, // This keeps Systolic/Diastolic visible even when filled!
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: _isEditing ? Colors.white : Colors.grey.shade200,
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade400)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade400)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2962FF), width: 2)),
      ),
    );
  }
}