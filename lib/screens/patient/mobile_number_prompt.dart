import 'package:flutter/material.dart';

import '../../core/auth_service.dart';
import '../../core/resident_visits.dart';
import 'app_colors.dart';
import 'edit_profile_screen.dart';
import 'patient_store.dart';
import 'ui_kit.dart';

/// Shown on the resident's home until they add a mobile number. Check-ups are
/// matched to a resident by name and mobile number, so without one their
/// Medical History stays empty (common after signing up with Google).
class MobileNumberPrompt extends StatelessWidget {
  const MobileNumberPrompt({super.key});

  Future<void> _open(BuildContext context) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    if (saved == true) ResidentVisits.instance.load(); // now they can match
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PatientStore.instance, // refreshed after Edit Profile saves
      builder: (context, _) {
        if (AuthService.instance.currentUser?.hasMobile ?? true) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: Sp.xl),
          child: AppCard(
            borderColor: AppColors.orangeText.withValues(alpha: 0.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add your mobile number', style: T.rowTitle),
                const SizedBox(height: Sp.xs),
                const Text(
                  'GoBikers record check-ups with your name and mobile number. '
                  'Add yours so your check-ups appear in your Medical History.',
                  style: T.secondary,
                ),
                const SizedBox(height: Sp.md),
                SecondaryButton(
                  label: 'Add mobile number',
                  onPressed: () => _open(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
