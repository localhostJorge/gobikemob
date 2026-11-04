import 'package:flutter/material.dart';

import '../../core/age.dart';
import '../../core/auth_service.dart';
import '../../widgets/birthday_field.dart';
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
  final _birthday = TextEditingController();
  String? _barangay;
  DateTime? _birthdate;

  // Values as loaded, to know if anything changed.
  String _initName = '';
  String _initMobile = '';
  String? _initBarangay;
  DateTime? _initBirthdate;

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
    _birthday.dispose();
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

    // Accounts made before the birthday was asked have none; they can add it here.
    _initBirthdate = user?.birthdate;
    _birthdate = _initBirthdate;
    _birthday.text = _birthdate == null ? '' : birthdateLabel(_birthdate!);
  }

  Future<void> _pickBirthday() async {
    final picked = await pickBirthday(context, current: _birthdate);
    if (picked == null || !mounted) return;
    // Setting the text counts as an edit, so the form checks the new date straight away.
    _birthday.text = birthdateLabel(picked);
    setState(() => _birthdate = picked);
  }

  bool get _dirty =>
      _name.text.trim() != _initName ||
      _mobile.text.trim() != _initMobile ||
      _barangay != _initBarangay ||
      _birthdate != _initBirthdate;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;

    setState(() => _saving = true);
    final result = await AuthService.instance.updateResidentProfile(
      name: _name.text,
      mobile: _mobile.text,
      barangay: _barangay!,
      birthdate: _birthdate,
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
      backgroundColor: context.pal.background,
      appBar: patientAppBar(context, 'Edit profile'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  Sp.gutter,
                  Sp.sm,
                  Sp.gutter,
                  Sp.lg,
                ),
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
                      const SizedBox(height: Sp.sm),
                      Text(
                        'Tap the camera to change your photo',
                        style: T.meta.muted(context),
                      ),
                      const SizedBox(height: Sp.xl),
                      TextFormField(
                        style: T.body.copyWith(color: context.pal.ink),
                        cursorColor: context.pal.ink,
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: inputDecoration(
                          context,
                          'Full name',
                          Icons.person_outline,
                        ),
                        validator: (v) => (v == null || v.trim().length < 2)
                            ? 'Enter your full name'
                            : null,
                      ),
                      const SizedBox(height: Sp.lg),
                      // Read-only: the email is the login and can't be changed here.
                      TextFormField(
                        controller: _email,
                        readOnly: true,
                        enableInteractiveSelection: true,
                        style: T.body.copyWith(color: context.pal.muted),
                        decoration:
                            inputDecoration(
                              context,
                              'Email',
                              Icons.email_outlined,
                              suffix: Icon(
                                Icons.lock_outline,
                                size: 18,
                                color: context.pal.muted,
                              ),
                            ).copyWith(
                              fillColor: context.pal.background,
                              helperText: "Your email is your login and can't be changed.",
                            ),
                      ),
                      const SizedBox(height: Sp.lg),
                      TextFormField(
                        style: T.body.copyWith(color: context.pal.ink),
                        cursorColor: context.pal.ink,
                        controller: _mobile,
                        keyboardType: TextInputType.phone,
                        decoration: inputDecoration(
                          context,
                          'Mobile number',
                          Icons.phone_outlined,
                        ),
                        validator: (v) =>
                            RegExp(r'^09\d{9}$').hasMatch(v?.trim() ?? '')
                            ? null
                            : 'Use 11 digits starting with 09',
                      ),
                      const SizedBox(height: Sp.lg),
                      // Tapping opens the date picker; the keyboard never opens.
                      TextFormField(
                        style: T.body.copyWith(color: context.pal.ink),
                        controller: _birthday,
                        readOnly: true,
                        onTap: _pickBirthday,
                        decoration: inputDecoration(
                          context,
                          'Birthday',
                          Icons.cake_outlined,
                          suffix: Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                            color: context.pal.muted,
                          ),
                        ).copyWith(
                          hintText: 'Select your birthday',
                          helperText: _birthdate == null
                              ? null
                              : 'You are ${ageFromBirthdate(_birthdate!, DateTime.now())} years old.',
                        ),
                        validator: (_) =>
                            birthdayError(_birthdate, required: false),
                      ),
                      const SizedBox(height: Sp.lg),
                      DropdownButtonFormField<String>(
                        style: T.body.copyWith(color: context.pal.ink),
                        dropdownColor: context.pal.card,
                        initialValue: _barangay,
                        isExpanded: true,
                        decoration: inputDecoration(
                          context,
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
            // The one main action, always in the same spot.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Sp.gutter,
                Sp.xs,
                Sp.gutter,
                Sp.lg,
              ),
              child: PrimaryButton(
                label: 'Save changes',
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
