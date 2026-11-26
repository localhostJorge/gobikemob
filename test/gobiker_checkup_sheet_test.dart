import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:go_bike_app/core/appointments.dart';
import 'package:go_bike_app/core/live_map.dart';
import 'package:go_bike_app/widgets/gobiker_checkup_sheet.dart';

MapPerson gobiker({
  String status = 'active',
  bool onRonda = false,
  String? barangay = 'Poblacion',
}) => MapPerson(
  id: 7,
  name: 'Maria Santos',
  latitude: 15.95,
  longitude: 120.18,
  status: status,
  onRonda: onRonda,
  barangay: barangay,
);

Appointment openVisit() => Appointment.fromJson({
  'id': 41,
  'status': 'pending',
  'status_label': 'Waiting for the GoBiker to accept',
  'barangay': 'Poblacion',
  'address': 'Purok 3',
  'preferred_date': DateTime.now()
      .add(const Duration(days: 2))
      .toIso8601String()
      .substring(0, 10),
  'preferred_window': 'morning',
  'window_label': 'Morning (8 AM – 12 PM)',
  'reason': 'Blood pressure check',
  'created_at': DateTime.now().toIso8601String(),
  'gobiker_id': 7,
  'gobiker_name': 'Maria Santos',
  'gobiker_barangay': 'Poblacion',
});

/// Whether the button with this label can be pressed.
bool canPress(WidgetTester tester, String label) =>
    tester
        .widget<ButtonStyleButton>(
          find.ancestor(
            of: find.text(label),
            matching: find.bySubtype<ButtonStyleButton>(),
          ),
        )
        .onPressed !=
    null;

void main() {
  group('the status line', () {
    test('says where a GoBiker on a ronda is', () {
      expect(
        GobikerCheckupSheet.statusLine(gobiker(onRonda: true)),
        'On ronda in Poblacion',
      );
      expect(
        GobikerCheckupSheet.statusLine(gobiker(onRonda: true, barangay: null)),
        'On ronda',
      );
    });

    test('says a GoBiker with the app open is online', () {
      expect(GobikerCheckupSheet.statusLine(gobiker()), 'Online · Poblacion');
      expect(GobikerCheckupSheet.statusLine(gobiker(barangay: null)), 'Online');
    });

    test('says a GoBiker on an SOS is busy, ronda or not', () {
      for (final status in ['emergency', 'responding']) {
        expect(
          GobikerCheckupSheet.statusLine(
            gobiker(status: status, onRonda: true),
          ),
          'Busy with an emergency right now',
        );
      }
    });
  });

  group('the sheet', () {
    late int requested;
    late int viewed;

    setUp(() {
      requested = 0;
      viewed = 0;
    });

    Future<void> show(
      WidgetTester tester, {
      required MapPerson who,
      Appointment? openRequest,
      bool atLimit = false,
    }) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GobikerCheckupSheet(
            gobiker: who,
            openRequest: openRequest,
            atLimit: atLimit,
            onRequest: () => requested++,
            onViewRequest: () => viewed++,
          ),
        ),
      ),
    );

    testWidgets('asks for a check-up from a GoBiker on a ronda', (
      tester,
    ) async {
      await show(tester, who: gobiker(onRonda: true));

      expect(find.text('Maria Santos'), findsOneWidget);
      expect(find.text('On ronda in Poblacion'), findsOneWidget);
      expect(canPress(tester, 'Request a check-up'), isTrue);

      await tester.tap(find.text('Request a check-up'));
      expect(requested, 1);
      expect(viewed, 0);
    });

    testWidgets('holds the button back while the GoBiker is on an SOS', (
      tester,
    ) async {
      await show(tester, who: gobiker(status: 'responding'));

      expect(find.text('Busy with an emergency right now'), findsOneWidget);
      expect(canPress(tester, 'Request a check-up'), isFalse);
      await tester.tap(find.text('Request a check-up'));
      expect(requested, 0);
    });

    testWidgets('opens the request already sent to this GoBiker', (
      tester,
    ) async {
      await show(tester, who: gobiker(), openRequest: openVisit());

      expect(
        find.text('You already asked Maria Santos for a check-up.'),
        findsOneWidget,
      );
      expect(find.text('Request a check-up'), findsNothing);

      await tester.tap(find.text('View request'));
      expect(viewed, 1);
      expect(requested, 0);
    });

    testWidgets('says so when three requests are already open', (tester) async {
      await show(tester, who: gobiker(), atLimit: true);

      expect(find.textContaining('You have 3 open requests'), findsOneWidget);
      expect(canPress(tester, 'Request a check-up'), isFalse);
    });
  });
}
