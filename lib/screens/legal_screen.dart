import 'package:flutter/material.dart';

import '../widgets/auth_widgets.dart';

enum LegalType { terms, privacy }

class _Section {
  const _Section(this.title, this.body);
  final String title;
  final String body;
}

const String _contactEmail = 'onegobike@gmail.com'; // TODO: replace
const String _lastUpdated = 'October 4, 2026';

const List<_Section> _termsSections = [
  _Section(
    'About Go Bike',
    "Go Bike Project is a community health-check program. Volunteer cyclist responders (\"Go Bikers\") visit residents on a scheduled \"ronda\", and the Go Bike admin coordinates them through this app. Go Bike supports your local health services; it is not a hospital or a clinic.",
  ),
  _Section(
    'Your account',
    "You must give accurate information when you sign up and keep your password private. You are responsible for activity under your account. Go Biker accounts need approval from an admin before they can be used, and an admin may deactivate any account that breaks these terms.",
  ),
  _Section(
    'Acceptable use',
    "Do not send false emergency alerts, fake your location, share other people's information, harass anyone, or try to break or misuse the app. Go Bikers must treat residents with respect and only record information needed for the check-up.",
  ),
  _Section(
    'Location sharing during a ronda',
    "When a Go Biker starts a ronda, the app shares their GPS location with the admins until the ronda ends. This lets the admin see where responders are and help them quickly, if emergency happen. Location is not shared outside an active ronda.",
  ),
  _Section(
    'Emergencies',
    "Go Bike does not replace emergency services. In a life-threatening emergency, call 911 or your local emergency hotline first. The in-app emergency button notifies the Go Bike admin and may not reach help as fast as a direct call.",
  ),
  _Section(
    'Health information',
    "Information in the app is for community check-ups and record keeping. It is not a medical diagnosis or medical advice. Please consult a licensed health professional for medical decisions.",
  ),
  _Section(
    'Availability',
    "We try to keep the app working, but it may be unavailable or change from time to time, for example during maintenance or when your internet connection is weak.",
  ),
  _Section(
    'Changes to these terms',
    "We may update these terms. When we do, we will update the date at the top of this page. Using the app after an update means you accept the new terms.",
  ),
  _Section(
    'Contact',
    "If you have questions about these terms you can email $_contactEmail.",
  ),
];

const List<_Section> _privacySections = [
  _Section(
    'Who we are',
    "Go Bike is the personal information controller for this app. We handle your personal information in line with the Data Privacy Act of 2012 (Republic Act No. 10173) of the Philippines.",
  ),
  _Section(
    'What we collect',
    "Account details: your name, email, mobile number, barangay, role and password. If you use Google sign-in: the name and email on your Google account.\n\nLocation: GPS coordinates of Go Bikers, only while a ronda is active.\n\nHealth-related notes: information Go Bikers record about residents during check-ups. This is sensitive personal information and we protect it more strictly.",
  ),
  _Section(
    'Why we collect it',
    "To create and secure your account, run ronda and check-ups, show admin where active Go Bikers are, respond to emergencies, and keep records of community health visits.",
  ),
  _Section(
    'Who can see it',
    "Go Bike admin can see account details, ronda records and live locations of active Go Bikers. We do not sell your information. We may share it with health authorities or emergency responders when needed to protect someone's life or health, or when the law requires it. Google receives your sign-in request only if you choose Google sign-in.",
  ),
  _Section(
    'Location',
    "Go Bikers' location is collected only while a ronda is active and stops when the ronda ends or you log out. Residents' location is not tracked.",
  ),
  _Section(
    'How long we keep it',
    "We keep information only as long as needed for the program, for record keeping required by health or local rules, or until you ask us to delete your account, whichever applies.",
  ),
  _Section(
    'How we protect it',
    "Passwords are protected, access to the admin panel is restricted to authorized staff, and the live app uses secure connections. No system is perfectly secure, so please keep your password private to the other users.",
  ),
  _Section(
    'Your rights',
    "Under the Data Privacy Act you have the right to be informed, to access your information, to object to its use, to correct it, to ask for it to be blocked or deleted, to claim damages if you were harmed by misuse, and to complain to the National Privacy Commission (privacy.gov.ph).",
  ),
  _Section(
    'Changes to this policy',
    "We may update this policy. When we do, we will update the date at the top of this page.",
  ),
  _Section(
    'Contact',
    "To use your rights or ask a question, email $_contactEmail.",
  ),
];

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.type});

  final LegalType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.6);

    final isTerms = type == LegalType.terms;
    final title = isTerms ? 'Terms of Service' : 'Privacy Policy';
    final intro = isTerms
        ? 'Please read these terms before using this App. By creating an account you agree to them.'
        : 'This policy explains what information Go Bike collects, why, and what choices you have.';
    final sections = isTerms ? _termsSections : _privacySections;

    return Scaffold(
      backgroundColor: authBackground(context),
      appBar: AppBar(
        backgroundColor: authBackground(context),
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Text(
              'Last updated: $_lastUpdated',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 12),
            Text(
              intro,
              style: TextStyle(fontSize: 14, height: 1.5, color: onSurface),
            ),
            const SizedBox(height: 24),
            for (var i = 0; i < sections.length; i++) ...[
              Text(
                '${i + 1}. ${sections[i].title}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                sections[i].body,
                style: TextStyle(fontSize: 14, height: 1.55, color: muted),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}
