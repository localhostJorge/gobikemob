import 'package:flutter/material.dart';

import '../../core/auth_service.dart';
import '../../core/resident_visits.dart';
import 'app_colors.dart';
import 'edit_profile_screen.dart';
import 'patient_store.dart';
import 'patient_ui.dart';

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
          padding: const EdgeInsets.only(bottom: 14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: cardDecoration().copyWith(
              border: Border.all(
                color: AppColors.orange.withValues(alpha: 0.6),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.phone_android_rounded, color: AppColors.orange),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Add your mobile number',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'GoBikers record check-ups with your name and mobile number. '
                  'Add yours so your check-ups appear in your Medical History.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: () => _open(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Add mobile number',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
