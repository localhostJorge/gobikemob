import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:go_bike_app/core/follow_up.dart';
import 'package:go_bike_app/screens/view_patient_screen.dart';
import 'package:go_bike_app/widgets/follow_up_banner.dart';

Map<String, dynamic> _patient({Map<String, dynamic>? followUp}) => {
  'id': '7',
  'date': 'October 12, 2026',
  'time': '03:00 PM',
  'name': 'Lola Nena',
  'address': 'Purok 2',
  'contact': '09181112222',
  'age': '72',
  'sys': '120',
  'dia': '78',
  'pulse': '70',
  'resp': '16',
  'temp': '36.5',
  'blood_sugar': '95',
  'barangay': 'Hacienda',
  'follow_up': followUp,
};

void main() {
  testWidgets('the chip says what the admin decided', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              FollowUpChip(followUp: FollowUp.from({'decision': 'stop'})!),
              FollowUpChip(followUp: FollowUp.from({'decision': 'continue'})!),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Stop checking'), findsOneWidget);
    expect(find.text('Keep checking'), findsOneWidget);
  });

  testWidgets('the record screen shows the admin decision and note', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ViewPatientScreen(
          patient: _patient(
            followUp: {
              'decision': 'stop',
              'note': 'Normal since July.',
              'decided_at': '2026-10-22T08:00:00+00:00',
            },
          ),
        ),
      ),
    );

    expect(find.text('No need for regular check-ups'), findsOneWidget);
    expect(find.textContaining('Normal since July.'), findsOneWidget);
    expect(find.textContaining('Decided Oct 2'), findsOneWidget);
  });

  testWidgets('the record screen shows no banner without a decision', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ViewPatientScreen(patient: _patient())),
    );

    expect(find.byType(FollowUpBanner), findsNothing);
  });
}
