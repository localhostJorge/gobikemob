import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/auth_service.dart';
import '../core/greeting.dart';
import '../core/theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/confirm_modal.dart';
import '../widgets/fade_in_slide.dart';
import '../widgets/profile_panel.dart';

class ResidentDashboardScreen extends StatefulWidget {
  const ResidentDashboardScreen({super.key});

  @override
  State<ResidentDashboardScreen> createState() =>
      _ResidentDashboardScreenState();
}

class _ResidentDashboardScreenState extends State<ResidentDashboardScreen>
    with WidgetsBindingObserver {
  bool _profileOpen = false;

  // TODO(api): announcements should come from the server.
  static const String _sampleAnnouncementTitle = 'Free Medicine';
  static const String _sampleAnnouncementBody =
      'Available at the RHU main center from 8 AM to 4 PM for all residents.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh the greeting when the app comes back to the foreground.
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  // ------------------------------------------------------------------ actions

  Future<void> _openProfile() async {
    setState(() => _profileOpen = true);
    await ProfilePanel.show(context);
    if (mounted) setState(() => _profileOpen = false);
  }

  Future<void> _call911() async {
    try {
      final opened = await launchUrl(Uri(scheme: 'tel', path: '911'));
      if (!opened && mounted) {
        AppToast.show(
          context,
          "Couldn't open the phone dialer. Please dial 911 manually.",
          type: ToastType.error,
        );
      }
    } catch (_) {
      if (mounted) {
        AppToast.show(
          context,
          "Couldn't open the phone dialer. Please dial 911 manually.",
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _onSos() async {
    final confirmed = await ConfirmModal.show(
      context: context,
      icon: Icons.warning_amber_rounded,
      color: AppTheme.errorRed,
      title: 'Need emergency help?',
      description:
          'Alerts to the admin are not connected in this version of the app yet. '
          'For immediate help, call 911 now.',
      confirmText: 'Call 911',
      onConfirm: () {},
    );
    if (confirmed == true) await _call911();
  }

  Future<void> _onRequestCheckup() async {
    final confirmed = await ConfirmModal.show(
      context: context,
      icon: Icons.calendar_month_rounded,
      color: AppTheme.blue,
      title: 'Request a check-up?',
      description: 'A Go Biker will visit your address the next time they are on a ronda in your barangay.',
      confirmText: 'Request',
      onConfirm: () {},
    );
    if (confirmed != true || !mounted) return;

    // TODO(api): check-up requests are saved on the server in step 3C.
    AppToast.show(
      context,
      'Check-up requests will be available in the next update.',
      type: ToastType.info,
    );
  }

  // -------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final user = AuthService.instance.currentUser;

    final barangay = (user?.barangay != null && user!.barangay!.isNotEmpty)
        ? 'Brgy. ${user.barangay}'
        : null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Greeting header
            FadeInSlide(
              offset: const Offset(0, -12),
              child: _buildHeader(
                theme,
                muted,
                user?.firstName ?? 'there',
                barangay,
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1) Emergency SOS (the primary action)
                    FadeInSlide(
                      delay: const Duration(milliseconds: 80),
                      child: _buildSosCard(),
                    ),
                    const SizedBox(height: 24),

                    // 2) Quick actions
                    FadeInSlide(
                      delay: const Duration(milliseconds: 160),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle('QUICK ACTIONS', muted),
                          Row(
                            children: [
                              Expanded(
                                child: _quickAction(
                                  theme,
                                  icon: Icons.calendar_month_rounded,
                                  color: AppTheme.blue,
                                  label: 'Request\nCheck-up',
                                  onTap: _onRequestCheckup,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _quickAction(
                                  theme,
                                  icon: Icons.phone_in_talk_rounded,
                                  color: AppTheme.successGreen,
                                  label: 'Call 911',
                                  onTap: _call911,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 3) Announcements
                    FadeInSlide(
                      delay: const Duration(milliseconds: 240),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle('COMMUNITY ANNOUNCEMENTS', muted),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: _cardDecoration(theme),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _iconBadge(
                                  Icons.campaign_rounded,
                                  AppTheme.orange,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        _sampleAnnouncementTitle,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _sampleAnnouncementBody,
                                        style: TextStyle(
                                          fontSize: 13,
                                          height: 1.4,
                                          color: muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom bar (Profile at the far right)
            FadeInSlide(
              delay: const Duration(milliseconds: 320),
              offset: const Offset(0, 24),
              child: _buildBottomBar(theme, muted),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ pieces

  BoxDecoration _cardDecoration(ThemeData theme, {bool shadow = false}) {
    final isLight = theme.brightness == Brightness.light;
    return BoxDecoration(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: theme.dividerColor),
      boxShadow: (shadow && isLight)
          ? const [
              BoxShadow(
                color: Color(0x141E1E48),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ]
          : null,
    );
  }

  Widget _sectionTitle(String text, Color muted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: muted,
        ),
      ),
    );
  }

  Widget _iconBadge(IconData icon, Color color) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    Color muted,
    String firstName,
    String? barangay,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Container(
            padding: isDark
                ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                : EdgeInsets.zero,
            decoration: BoxDecoration(
              color: isDark ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset(
              'assets/images/logo.png',
              height: 36,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.directions_bike_rounded,
                color: AppTheme.blue,
                size: 32,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greetingForNow(),
                  style: TextStyle(fontSize: 13, color: muted),
                ),
                const SizedBox(height: 2),
                Text(
                  firstName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (barangay != null)
                  Text(barangay, style: TextStyle(fontSize: 12, color: muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSosCard() {
    return InkWell(
      onTap: _onSos,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.errorRed,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.errorRed.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Column(
          children: [
            Icon(Icons.emergency_share_rounded, color: Colors.white, size: 48),
            SizedBox(height: 10),
            Text(
              'EMERGENCY SOS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Tap to request immediate medical help',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(
    ThemeData theme, {
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: _cardDecoration(theme),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme, Color muted) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: _cardDecoration(
        theme,
        shadow: true,
      ).copyWith(borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          _NavItem(
            icon: Icons.home_rounded,
            label: 'Home',
            selected: !_profileOpen,
            muted: muted,
            onTap: () {},
          ),
          _NavItem(
            icon: Icons.person_rounded,
            label: 'Profile',
            selected: _profileOpen,
            muted: muted,
            onTap: _openProfile,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.muted,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.blue : muted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.blue.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 26, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
