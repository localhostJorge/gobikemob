import 'package:flutter/material.dart';

import '../../core/auth_service.dart';
import '../auth_database.dart';
import '../welcome_screen.dart';
import 'app_colors.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'notification_settings_screen.dart';
import 'patient_store.dart';
import 'patient_ui.dart';
import 'profile_avatar.dart';

class ProfileScreen extends StatelessWidget {
  final AppUser currentUser;

  const ProfileScreen({super.key, required this.currentUser});

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to log in again to use the app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out',
                style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    AuthDatabase.instance.logout();
    PatientStore.instance.clearSession();
    // TODO: also clear your auth_service / global_state session here.

    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: patientAppBar(context, 'Profile'),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: PatientStore.instance,
          builder: (context, _) {
            final store = PatientStore.instance;
            final name = store.fullName ?? currentUser.name;
            final phone = store.mobile ?? currentUser.mobile ?? '';

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                children: [
                  ProfileAvatar(
                    radius: 52,
                    showCamera: true,
                    onCameraTap: () => changeProfilePhoto(context),
                  ),
                  const SizedBox(height: 14),
                  Text(name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark)),
                  const SizedBox(height: 2),
                  Text(phone,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textMuted)),
                  const SizedBox(height: 28),
                  _row(Icons.person_outline, 'Edit Profile',
                      () => _open(context, const EditProfileScreen())),
                  const SizedBox(height: 10),
                  _row(Icons.lock_outline, 'Change Password',
                      () => _open(context, const ChangePasswordScreen())),
                  const SizedBox(height: 10),
                  _row(
                      Icons.notifications_none_rounded,
                      'Notification Settings',
                      () =>
                          _open(context, const NotificationSettingsScreen())),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _logout(context),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout_rounded,
                                color: AppColors.red, size: 20),
                            SizedBox(width: 8),
                            Text('Logout',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.red)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.redSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.red, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark)),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}