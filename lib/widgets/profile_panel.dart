import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/auth_service.dart';
import '../core/theme.dart';
import '../core/tracking_service.dart';
import '../screens/legal_screen.dart';
import '../screens/login_screen.dart';
import 'app_toast.dart';
import 'confirm_modal.dart';
import '../screens/global_state.dart';
import '../core/ronda_store.dart';

class ProfilePanel {
  /// Opens the profile panel, sliding in from the right.
  static Future<void> show(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close profile',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, _, _) =>
          _ProfilePanelBody(rootContext: context),
      transitionBuilder: (context, animation, _, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                ),
              ),
          child: child,
        );
      },
    );
  }

  /// Stops tracking, logs out on the server, clears the saved session and
  /// returns to the Login screen. [context] must belong to a screen that
  /// stays mounted (the dashboard), not to the panel itself.
  static Future<void> logout(BuildContext context) async {
    if (!context.mounted) return;
    final navigator = Navigator.of(context);

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.35),
        builder: (_) => const PopScope(
          canPop: false,
          child: Center(child: _LoadingCard(message: 'Logging out...')),
        ),
      ),
    );

    await TrackingService.instance.stopRonda();
    await RondaStore.clear(); // a killed ronda must not leak to the next login
    await AuthService.instance.logout();

    globalPatients
        .clear(); // private health data: never keep it for the next person
    globalRondas.clear();

    if (!context.mounted) return;
    AppToast.show(context, 'You have been logged out', type: ToastType.success);
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _ProfilePanelBody extends StatelessWidget {
  const _ProfilePanelBody({required this.rootContext});

  /// The dashboard's context; it stays alive after the panel closes.
  final BuildContext rootContext;

  String _roleLabel(AppUser user) {
    if (user.isGoBiker) return 'Go Biker';
    if (user.isResident) return 'Resident';
    return user.role;
  }

  String _memberSince(String? raw) {
    final date = DateTime.tryParse(raw ?? '');
    return date == null ? '—' : DateFormat('MMMM d, yyyy').format(date);
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
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
    if (!context.mounted) return;

    Navigator.of(context).pop(); // close the panel
    await ProfilePanel.logout(rootContext);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.6);
    final user = AuthService.instance.currentUser;
    final width = (MediaQuery.of(context).size.width * 0.84).clamp(
      280.0,
      380.0,
    );

    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: width,
        height: double.infinity,
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            bottomLeft: Radius.circular(28),
          ),
          clipBehavior: Clip.antiAlias,
          child: GestureDetector(
            // Swipe right to close
            onHorizontalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) > 300) Navigator.of(context).pop();
            },
            child: SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                      child: IconButton(
                        tooltip: 'Close',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Identity
                          Center(
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 38,
                                  backgroundColor: AppTheme.blue.withValues(
                                    alpha: 0.14,
                                  ),
                                  child: Text(
                                    _initials(user?.name ?? ''),
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.blue,
                                    ),
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
                                    color: AppTheme.blue.withValues(
                                      alpha: 0.12,
                                    ),
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

                          _SectionLabel('PERSONAL INFORMATION', muted),
                          _InfoRow(
                            Icons.mail_outline_rounded,
                            'Email',
                            user?.email,
                          ),
                          _InfoRow(
                            Icons.phone_outlined,
                            'Mobile',
                            user?.mobile,
                          ),
                          _InfoRow(
                            Icons.location_on_outlined,
                            'Barangay',
                            user?.barangay,
                          ),
                          _InfoRow(
                            Icons.badge_outlined,
                            'Role',
                            user == null ? null : _roleLabel(user),
                          ),
                          _InfoRow(
                            Icons.event_outlined,
                            'Member since',
                            _memberSince(user?.memberSince),
                          ),
                          const SizedBox(height: 24),

                          _SectionLabel('APPEARANCE', muted),
                          ListenableBuilder(
                            listenable: ThemeController.instance,
                            builder: (context, _) {
                              final isDark =
                                  Theme.of(context).brightness ==
                                  Brightness.dark;
                              return Row(
                                children: [
                                  Icon(
                                    Icons.dark_mode_outlined,
                                    size: 22,
                                    color: muted,
                                  ),
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
                                    activeTrackColor: AppTheme.blue,
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
                            label: 'Terms of Service',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const LegalScreen(type: LegalType.terms),
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
                        ],
                      ),
                    ),
                  ),

                  // Logout pinned at the bottom
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmLogout(context),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text(
                        'Log out',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorRed,
                        side: const BorderSide(color: AppTheme.errorRed),
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: color,
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
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

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
            Icon(icon, size: 22, color: muted),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
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
