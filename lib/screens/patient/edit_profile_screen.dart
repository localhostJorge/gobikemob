import 'package:flutter/material.dart';

import '../../core/auth_service.dart';
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
  String _initMobile = '';
  String? _initBarangay;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _mobile]) {
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

  void _load() {
    final user = AuthService.instance.currentUser;

    _initName = user?.name ?? '';
    _initMobile = user?.mobile ?? '';
    // Only offer a barangay the server accepts; an old free-text one must be re-picked.
    final barangay = user?.barangay;
    _initBarangay =
        (kLocations['Bugallon'] ?? const <String>[]).contains(barangay)
        ? barangay
        : null;

    _name.text = _initName;
    _email.text = user?.email ?? '';
    _mobile.text = _initMobile;
    _barangay = _initBarangay;
  }

  bool get _dirty =>
      _name.text.trim() != _initName ||
      _mobile.text.trim() != _initMobile ||
      _barangay != _initBarangay;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;

    setState(() => _saving = true);
    final result = await AuthService.instance.updateResidentProfile(
      name: _name.text,
      mobile: _mobile.text,
      barangay: _barangay!,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    final messenger = ScaffoldMessenger.of(context);
    if (!result.ok) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(result.message)));
      return;
    }

    PatientStore.instance.refreshProfile();
    if (!mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Profile updated')));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final barangays = kLocations['Bugallon'] ?? const <String>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: patientAppBar(context, 'Edit Profile'),
      body: SafeArea(
        child: Column(
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
                      const Text(
                        'Tap the camera to change your photo',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 22),
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: inputDecoration(
                          'Full Name',
                          Icons.person_outline,
                        ),
                        validator: (v) => (v == null || v.trim().length < 2)
                            ? 'Enter your full name'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      // Read-only: the email is the login and can't be changed here.
                      TextFormField(
                        controller: _email,
                        readOnly: true,
                        enableInteractiveSelection: true,
                        style: const TextStyle(color: AppColors.textMuted),
                        decoration:
                            inputDecoration(
                              'Email',
                              Icons.email_outlined,
                              suffix: const Icon(
                                Icons.lock_outline,
                                size: 18,
                                color: AppColors.textMuted,
                              ),
                            ).copyWith(
                              fillColor: AppColors.background,
                              helperText: "Your email is your login and can't be changed.",
                            ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _mobile,
                        keyboardType: TextInputType.phone,
                        decoration: inputDecoration(
                          'Mobile Number',
                          Icons.phone_outlined,
                        ),
                        validator: (v) =>
                            RegExp(r'^09\d{9}$').hasMatch(v?.trim() ?? '')
                            ? null
                            : 'Use 11 digits starting with 09',
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _barangay,
                        isExpanded: true,
                        decoration: inputDecoration(
                          'Barangay',
                          Icons.map_outlined,
                        ),
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
