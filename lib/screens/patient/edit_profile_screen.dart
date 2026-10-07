import 'package:flutter/material.dart';

import '../auth_database.dart';
import 'app_colors.dart';
import 'emergency_request_screen.dart' show kLocations;
import 'patient_store.dart';
import 'patient_ui.dart';
import 'profile_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  String? _barangay;

  // Values as loaded, to know if anything changed.
  String _initName = '';
  String _initEmail = '';
  String _initMobile = '';
  String? _initBarangay;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _email, _mobile]) {
      c.addListener(() => setState(() {}));
    }
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _mobile.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final row = await AuthDatabase.instance.currentUserRow();
    final s = PatientStore.instance;
    if (!mounted) return;

    _initName = (row?['full_name'] as String?) ?? s.fullName ?? '';
    _initEmail = (row?['email'] as String?) ?? s.email ?? '';
    _initMobile = (row?['mobile'] as String?) ?? s.mobile ?? '';
    _initBarangay = (row?['barangay'] as String?) ?? s.barangay;

    _name.text = _initName;
    _email.text = _initEmail;
    _mobile.text = _initMobile;
    setState(() {
      _barangay = _initBarangay;
      _loading = false;
    });
  }

  bool get _dirty =>
      _name.text.trim() != _initName ||
      _email.text.trim() != _initEmail ||
      _mobile.text.trim() != _initMobile ||
      _barangay != _initBarangay;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;

    setState(() => _saving = true);
    final error = await AuthDatabase.instance.updateProfile(
      fullName: _name.text,
      email: _email.text,
      mobile: _mobile.text,
      barangay: _barangay!,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    final messenger = ScaffoldMessenger.of(context);
    if (error != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    await PatientStore.instance.refreshProfile();
    if (!mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Profile updated')));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final barangays = <String>{
      ...(kLocations['Bugallon'] ?? const <String>[]),
      if (_barangay != null) _barangay!,
    }.toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: patientAppBar(context, 'Edit Profile'),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.red))
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Form(
                        key: _form,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          children: [
                            Center(
                              child: ProfileAvatar(
                                radius: 52,
                                showCamera: true,
                                onCameraTap: () => changeProfilePhoto(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text('Tap the camera to change your photo',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.textMuted)),
                            const SizedBox(height: 22),
                            TextFormField(
                              controller: _name,
                              textCapitalization: TextCapitalization.words,
                              decoration: inputDecoration(
                                  'Full Name', Icons.person_outline),
                              validator: (v) =>
                                  (v == null || v.trim().length < 2)
                                      ? 'Enter your full name'
                                      : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: inputDecoration(
                                  'Email', Icons.email_outlined),
                              validator: (v) {
                                final t = v?.trim() ?? '';
                                final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                    .hasMatch(t);
                                return ok ? null : 'Enter a valid email';
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _mobile,
                              keyboardType: TextInputType.phone,
                              decoration: inputDecoration(
                                  'Mobile Number', Icons.phone_outlined),
                              validator: (v) {
                                final digits =
                                    (v ?? '').replaceAll(RegExp(r'\D'), '');
                                return (digits.length < 10 ||
                                        digits.length > 13)
                                    ? 'Enter a valid mobile number'
                                    : null;
                              },
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              value: _barangay,
                              isExpanded: true,
                              decoration: inputDecoration(
                                  'Barangay', Icons.map_outlined),
                              items: [
                                for (final b in barangays)
                                  DropdownMenuItem(value: b, child: Text(b)),
                              ],
                              onChanged: (v) => setState(() => _barangay = v),
                              validator: (v) =>
                                  v == null ? 'Select your barangay' : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: primaryButton(
                      label: 'SAVE CHANGES',
                      loading: _saving,
                      onPressed: _dirty ? _save : null,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}