import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/auth_service.dart';
import '../core/gobiker_history.dart';
import '../core/theme.dart';
import '../screens/patient/app_colors.dart';
import '../screens/patient/ui_kit.dart';
import '../core/tracking_service.dart';
import '../screens/legal_screen.dart';
import '../screens/login_screen.dart';
import '../screens/gobiker_edit_profile_screen.dart';
import 'app_toast.dart';
import 'brand.dart';
import 'confirm_modal.dart';
import 'delete_account_sheet.dart';
import 'loading_card.dart';
import 'initials_avatar.dart';
import 'photo_flow.dart';
import 'two_step_login_tile.dart';
import '../screens/global_state.dart';
import '../core/ronda_store.dart';

class ProfilePanel {
  /// Stops tracking, logs out on the server, clears the saved session and
  /// returns to the Login screen. [context] must belong to a screen that
  /// stays mounted (the GoBiker home and its Profile tab).
  static Future<void> logout(BuildContext context) async {
    if (!context.mounted) return;
    final navigator = Navigator.of(context);

    showLoggingOut(context);

    await TrackingService.instance.stopRonda();
    await RondaStore.clear(); // a killed ronda must not leak to the next login
    await AuthService.instance.logout();
    _clearGobikerData();

    if (!context.mounted) return;
    AppToast.show(context, 'You have been logged out', type: ToastType.success);
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  /// After "Delete account" succeeded (the session is already gone): clears what the GoBiker
  /// had on this phone and returns to the Login screen. No ronda is running: the sheet asks to
  /// end it first.
  static Future<void> leaveAfterAccountDeleted(BuildContext context) async {
    if (!context.mounted) return;
    final navigator = Navigator.of(context);

    await RondaStore.clear();
    await RondaStore.setPendingStop(
      false,
    ); // nothing left on the server to stop
    _clearGobikerData();

    if (!context.mounted) return;
    AppToast.show(
      context,
      'Your account has been deleted',
      type: ToastType.success,
    );
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  static void _clearGobikerData() {
    globalPatients
        .clear(); // private health data: never keep it for the next person
    globalRondas.clear();
    GobikerHistory.instance.reset();
  }
}

/// The GoBiker's Profile tab: who they are, their settings, the legal pages, their
/// account, and Log out. A page of its own with the bottom bar still showing, like the
/// resident Profile tab.
class GobikerProfileTab extends StatefulWidget {
  const GobikerProfileTab({super.key});

  @override
  State<GobikerProfileTab> createState() => _GobikerProfileTabState();
}

class _GobikerProfileTabState extends State<GobikerProfileTab> {
  /// The installed app's version, shown under "About".
  final Future<PackageInfo> _appInfo = PackageInfo.fromPlatform();

  String _roleLabel(AppUser user) {
    if (user.isGoBiker) return 'GoBiker';
    if (user.isResident) return 'Resident';
    return user.role;
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await ConfirmModal.show(
      context: context,
      icon: Icons.logout_rounded,
      color: AppTheme.errorRed,
      title: 'Log out?',
      description: 'You will need to sign in again.',
      confirmText: 'Log out',
      onConfirm: () {},
    );
    if (confirmed != true) return;
    if (!mounted) return;

    await ProfilePanel.logout(this.context);
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final deleted = await showDeleteAccountSheet(context);
    if (!deleted || !mounted) return;

    await ProfilePanel.leaveAfterAccountDeleted(this.context);
  }

  /// Takes or picks a photo and sends it to the server.
  Future<void> _changePhoto(BuildContext context) async {
    final picked = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted || !context.mounted) return;

    // Pick, then crop: the photo is not uploaded until the person has framed it.
    final String? path;
    try {
      path = await pickProfilePhoto(context, picked);
    } catch (_) {
      if (mounted && context.mounted) {
        AppToast.show(
          context,
          "Couldn't open the camera or gallery.",
          type: ToastType.error,
        );
      }
      return;
    }
    if (path == null || !mounted || !context.mounted) return;

    final error = await AuthService.instance.uploadProfilePhoto(path);
    if (!mounted || !context.mounted) return;
    if (error == null) setState(() {});
    AppToast.show(
      context,
      error ?? 'Profile photo updated.',
      type: error == null ? ToastType.success : ToastType.error,
    );
  }

  Future<void> _editProfile(BuildContext context, AppUser user) async {
    // A page of its own, not a pop-up: there is a lot to fill in.
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => GobikerEditProfileScreen(user: user)),
    );
    if (!mounted || !context.mounted) return;
    if (updated == true) {
      setState(() {});
      AppToast.show(context, 'Profile updated.', type: ToastType.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.6);
    final user = AuthService.instance.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TabHeader('Profile'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              Sp.gutter,
              Sp.sm,
              Sp.gutter,
              Sp.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Identity
                Center(
                  child: Column(
                    children: [
                      InitialsAvatar(
                        user?.name ?? '',
                        imageUrl: user?.photoUrl,
                        radius: 38,
                        fontSize: 26,
                      ),
                      // GoBikers now send a photo when they sign up.
                      // Anyone who joined earlier can add one here.
                      if (user != null && user.isGoBiker)
                        TextButton.icon(
                          onPressed: () => _changePhoto(context),
                          icon: Icon(
                            user.photoUrl == null
                                ? Icons.add_a_photo_outlined
                                : Icons.photo_camera_outlined,
                            size: 16,
                          ),
                          label: Text(
                            user.photoUrl == null
                                ? 'Add your photo'
                                : 'Change photo',
                          ),
                        ),
                      const SizedBox(height: 14),
                      Text(
                        user?.name ?? 'Guest',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          user == null ? '' : _roleLabel(user),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                Row(
                  children: [
                    Expanded(
                      child: _SectionLabel('PERSONAL INFORMATION', muted),
                    ),
                    if (user != null && user.isGoBiker)
                      TextButton.icon(
                        onPressed: () => _editProfile(context, user),
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: const Text('Edit'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Column(
                    children: [
                      _InfoRow(
                        Icons.mail_outline_rounded,
                        'Email',
                        user?.email,
                      ),
                      _InfoRow(Icons.phone_outlined, 'Mobile', user?.mobile),
                      _InfoRow(
                        Icons.location_on_outlined,
                        'Barangay',
                        user?.barangay,
                      ),
                      _InfoRow(
                        Icons.cake_outlined,
                        'Age',
                        user?.age == null ? null : '${user!.age} years old',
                      ),
                      _InfoRow(
                        Icons.badge_outlined,
                        'Role',
                        user == null ? null : _roleLabel(user),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                _SectionLabel('APPEARANCE', muted),
                ListenableBuilder(
                  listenable: ThemeController.instance,
                  builder: (context, _) {
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
                    return Row(
                      children: [
                        Icon(Icons.dark_mode_outlined, size: 22, color: muted),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'Dark mode',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Switch(
                          value: isDark,
                          activeThumbColor: Colors.white,
                          onChanged: (v) =>
                              ThemeController.instance.setThemeMode(
                                v ? ThemeMode.dark : ThemeMode.light,
                              ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                _SectionLabel('LEGAL', muted),
                _LinkRow(
                  icon: Icons.description_outlined,
                  label: 'Terms & Conditions',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const LegalScreen(type: LegalType.terms),
                    ),
                  ),
                ),
                _LinkRow(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy Policy',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const LegalScreen(type: LegalType.privacy),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                _SectionLabel('ACCOUNT', muted),
                const TwoStepLoginSettings(inCard: false),
                _LinkRow(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete account',
                  color: AppTheme.errorRed,
                  onTap: () => _deleteAccount(context),
                ),
                const SizedBox(height: 24),

                _SectionLabel('ABOUT', muted),
                FutureBuilder<PackageInfo>(
                  future: _appInfo,
                  builder: (context, snap) =>
                      GoBikeAbout(version: snap.data?.version),
                ),
                const SizedBox(height: 28),
                OutlinedButton.icon(
                  onPressed: () => _confirmLogout(context),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text(
                    'Log out',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.pal.redText,
                    side: BorderSide(color: context.pal.redText),
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        sentenceCase(text),
        style: TextStyle(
          fontFamily: kHeadingFont,
          fontSize: 16,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: context.pal.heading,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface
        .withValues(alpha: 0.6);
    final text = (value == null || value!.trim().isEmpty) ? '—' : value!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: muted),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: muted)),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// The icon and label color, e.g. red for Delete account; muted icon when null.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface
        .withValues(alpha: 0.6);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color ?? muted),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: muted),
          ],
        ),
      ),
    );
  }
}
