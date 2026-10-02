import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'auth_database.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  String selectedRole = 'Resident';
  String? selectedBarangay;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;
  bool _isLoading = false;

  final List<String> barangays = [
    'Angarian', 'Asinan', 'Bañaga', 'Bacabac', 'Bolaoen', 'Buenlag',
    'Cabayaoasan', 'Cayanga', 'Gueset', 'Hacienda', 'Laguit Centro',
    'Laguit Padilla', 'Magtaking', 'Pangascasan', 'Pantal', 'Poblacion',
    'Polong', 'Portic', 'Salasa', 'Salomague Norte', 'Salomague Sur',
    'Samat', 'San Francisco', 'Umanday'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateAccount() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedBarangay == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Barangay')));
      return;
    }
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must accept the Terms of Service')));
      return;
    }

    setState(() => _isLoading = true);

    final error = await AuthDatabase.instance.register(
      fullName: _nameController.text,
      email: _emailController.text,
      mobile: _mobileController.text,
      barangay: selectedBarangay!,
      role: selectedRole,
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account Created Successfully!')));
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // This hides the keyboard when you tap anywhere outside a text field
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        // Allows the screen to shrink and scroll when the keyboard opens
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: Image.asset('assets/images/logo.png', height: 70)),
                  const SizedBox(height: 20),

                  // Role Selection
                  Row(
                    children: [
                      Expanded(child: _buildRoleCard('Resident', Icons.person, 'Request check-ups')),
                      const SizedBox(width: 10),
                      Expanded(child: _buildRoleCard('GoBiker', Icons.medical_services, 'Manage visits')),
                    ],
                  ),
                  const SizedBox(height: 25),

                  // Input Fields
                  _buildLabel('Full Name'),
                  _buildTextField(
                    'Abinesh Jino',
                    Icons.person_outline,
                    controller: _nameController,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your full name' : null,
                  ),

                  _buildLabel('Email address'),
                  _buildTextField(
                    'Email Address',
                    Icons.mail_outline,
                    controller: _emailController,
                    isEmail: true,
                    validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),

                  _buildLabel('Mobile number'),
                  _buildTextField(
                    'Mobile Number',
                    Icons.phone_outlined,
                    controller: _mobileController,
                    isPhone: true,
                    validator: (v) => (v == null || v.trim().length < 10) ? 'Enter a valid mobile number' : null,
                  ),

                  _buildLabel('Barangay'),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.location_on_outlined, color: Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.grey)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    ),
                    hint: const Text('Select Barangay', style: TextStyle(color: Colors.grey, fontSize: 14)),
                    value: selectedBarangay,
                    items: barangays.map((String b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                    onChanged: (newValue) => setState(() => selectedBarangay = newValue),
                  ),
                  const SizedBox(height: 15),

                  _buildLabel('Create a Password'),
                  _buildPasswordField(
                    'Enter a Password',
                    _obscurePassword,
                    () => setState(() => _obscurePassword = !_obscurePassword),
                    controller: _passwordController,
                    validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
                  ),

                  _buildLabel('Confirm Password'),
                  _buildPasswordField(
                    'Retype Password',
                    _obscureConfirmPassword,
                    () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    controller: _confirmController,
                    validator: (v) => v != _passwordController.text ? 'Passwords do not match' : null,
                  ),

                  const SizedBox(height: 10),

                  // Terms Checkbox
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: _acceptedTerms,
                          onChanged: (value) => setState(() => _acceptedTerms = value!),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RichText(
                          text: const TextSpan(
                            text: 'By Signing up you accept our ',
                            style: TextStyle(color: Colors.black87, fontSize: 12),
                            children: [
                              TextSpan(text: 'Terms of Service', style: TextStyle(color: Color(0xFF2962FF), fontWeight: FontWeight.w500)),
                              TextSpan(text: ' & '),
                              TextSpan(text: 'Privacy Policy', style: TextStyle(color: Color(0xFF2962FF), fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),

                  // Primary Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleCreateAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2962FF),
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Get Set to Explore', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                            ],
                          ),
                  ),
                  const SizedBox(height: 15),

                  // Secondary Button
                  OutlinedButton(
                    onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen())),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 55),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: RichText(
                      text: const TextSpan(
                        text: 'Already a Member ? ',
                        style: TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
                        children: [
                          TextSpan(text: 'Login Now', style: TextStyle(color: Color(0xFF2962FF), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // UI Helpers
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
    );
  }

  Widget _buildTextField(
    String hint,
    IconData icon, {
    required TextEditingController controller,
    bool isEmail = false,
    bool isPhone = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: isEmail ? TextInputType.emailAddress : isPhone ? TextInputType.phone : TextInputType.text,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey, size: 22),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.grey)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
        ),
      ),
    );
  }

  Widget _buildPasswordField(
    String hint,
    bool obscure,
    VoidCallback onToggle, {
    required TextEditingController controller,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: TextFormField(
        controller: controller,
        validator: validator,
        obscureText: obscure,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey, size: 22),
          suffixIcon: IconButton(
            icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey, size: 20),
            onPressed: onToggle,
          ),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.grey)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
        ),
      ),
    );
  }

  Widget _buildRoleCard(String role, IconData icon, String subtitle) {
    bool isSelected = selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => selectedRole = role),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0F4FF) : Colors.white,
          border: Border.all(color: isSelected ? const Color(0xFF2962FF) : Colors.grey.shade300, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: isSelected ? const Color(0xFF2962FF) : Colors.grey),
            const SizedBox(height: 5),
            Text(role, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? const Color(0xFF2962FF) : Colors.black87)),
            Text(subtitle, style: const TextStyle(fontSize: 9, color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}