import 'package:flutter/material.dart';

import '../../core/auth_service.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/loading_card.dart';
import '../login_screen.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'notification_settings_screen.dart';
import 'patient_store.dart';
import 'profile_avatar.dart';
import 'settings_screen.dart';
import 'ui_kit.dart';

/// The Profile tab: who you are, your account, how the app behaves, and Log out.
/// The settings live here, so there is no separate Settings tab.
class ProfileTab extends StatelessWidget {
  final AppUser currentUser;

  const ProfileTab({super.key, required this.currentUser});

  Future<void> _logout(BuildContext context) async {
    final ok = await showConfirm(
      context,
      title: 'Log out?',
      message: 'You will need to log in again to use the app.',
      confirmLabel: 'Log out',
      destructive: true,
    );
    if (!ok || !context.mounted) return;

    // The root navigator outlives this tab, which goes away with the stack below.
    final navigator = Navigator.of(context, rootNavigator: true);
    showLoggingOut(context, useRootNavigator: true);

    await AuthService.instance.logout();
    PatientStore.instance.clearSession();
    if (!context.mounted) return;

    AppToast.show(context, 'You have been logged out', type: ToastType.success);
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TabHeader('Profile'),
        Expanded(
          child: ListenableBuilder(
            listenable: PatientStore.instance,
            builder: (context, _) {
              final store = PatientStore.instance;
              final name = store.fullName ?? currentUser.name;
              final phone = store.mobile ?? currentUser.mobile ?? '';
              final barangay = store.barangay ?? currentUser.barangay ?? '';
              final age = (AuthService.instance.currentUser ?? currentUser).age;
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
                      radius: 44,
                      showCamera: true,
                      onCameraTap: () => changeProfilePhoto(context),
                    ),
                  ),
                  const SizedBox(height: Sp.md),
                  Text(name, textAlign: TextAlign.center, style: T.title),
                  for (final line in [
                    phone,
                    barangay,
                    if (age != null) 'Age $age',
                  ])
                    if (line.isNotEmpty) ...[
                      const SizedBox(height: Sp.xs),
                      Text(
                        line,
                        textAlign: TextAlign.center,
                        style: T.secondary.muted(context),
                      ),
                    ],
                  const SizedBox(height: Sp.xl),
                  const SectionHeader('Account'),
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
                        title: setPassword
                            ? 'Set a password'
                            : 'Change password',
                        subtitle: setPassword
                            ? 'Also log in with your email'
                            : 'Use at least 8 characters',
                        onTap: () =>
                            _open(context, const ChangePasswordScreen()),
                      ),
                    ],
                  ),
                  const SizedBox(height: Sp.xl),
                  const SectionHeader('Preferences'),
                  CardGroup(
                    dividerIndent: 52,
                    children: [
                      const DarkModeRow(),
                      NavRow(
                        icon: Icons.notifications_none_rounded,
                        title: 'Notification settings',
                        subtitle: 'Choose which alerts you receive',
                        onTap: () =>
                            _open(context, const NotificationSettingsScreen()),
                      ),
                    ],
                  ),
                  const SizedBox(height: Sp.xl),
                  const SectionHeader('Emergency SOS'),
                  const SosHoldTimeCard(),
                  const SizedBox(height: Sp.xl),
                  const SectionHeader('About'),
                  const CardGroup(children: [AboutRow()]),
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
      ],
    );
  }
}
