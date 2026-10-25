import 'package:flutter/material.dart';

import '../../core/auth_service.dart';
import '../welcome_screen.dart';
import 'app_colors.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'notification_settings_screen.dart';
import 'patient_store.dart';
import 'profile_avatar.dart';
import 'ui_kit.dart';

class ProfileScreen extends StatelessWidget {
  final AppUser currentUser;

  const ProfileScreen({super.key, required this.currentUser});

  Future<void> _logout(BuildContext context) async {
    final ok = await showConfirm(
      context,
      title: 'Log out?',
      message: 'You will need to log in again to use the app.',
      confirmLabel: 'Log out',
      destructive: true,
    );
    if (!ok || !context.mounted) return;

    await AuthService.instance.logout();
    PatientStore.instance.clearSession();
    if (!context.mounted) return;

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
            final setPassword =
                AuthService.instance.currentUser?.hasPassword == false;

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                Sp.gutter,
                Sp.sm,
                Sp.gutter,
                Sp.xl,
              ),
              children: [
                Center(
                  child: ProfileAvatar(
                    radius: 48,
                    showCamera: true,
                    onCameraTap: () => changeProfilePhoto(context),
                  ),
                ),
                const SizedBox(height: Sp.lg),
                Text(name, textAlign: TextAlign.center, style: T.title),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: Sp.xs),
                  Text(phone, textAlign: TextAlign.center, style: T.secondary),
                ],
                const SizedBox(height: Sp.xl + Sp.sm),
                CardGroup(
                  dividerIndent: 52,
                  children: [
                    NavRow(
                      icon: Icons.person_outline_rounded,
                      title: 'Edit profile',
                      subtitle: 'Name, mobile number and barangay',
                      onTap: () => _open(context, const EditProfileScreen()),
                    ),
                    NavRow(
                      icon: Icons.lock_outline_rounded,
                      title: setPassword ? 'Set a password' : 'Change password',
                      subtitle: setPassword
                          ? 'Also log in with your email'
                          : 'Use at least 8 characters',
                      onTap: () => _open(context, const ChangePasswordScreen()),
                    ),
                    NavRow(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notification settings',
                      subtitle: 'Choose which alerts you receive',
                      onTap: () =>
                          _open(context, const NotificationSettingsScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: Sp.xl + Sp.sm),
                // Leaving is not the main action here, and sits apart.
                SecondaryButton(
                  label: 'Log out',
                  icon: Icons.logout_rounded,
                  destructive: true,
                  onPressed: () => _logout(context),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
