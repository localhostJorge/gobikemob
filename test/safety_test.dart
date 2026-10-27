import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_bike_app/core/hotlines.dart';
import 'package:go_bike_app/core/resident_sos.dart';
import 'package:go_bike_app/screens/patient/safety_tab.dart';

void main() {
  group('hotlines', () {
    test('every number is digits only, so the dialer gets it right', () {
      for (final h in [
        kNationalEmergency,
        ...kEmergencyHotlines,
        ...kUtilityHotlines,
      ]) {
        for (final n in h.numbers) {
          expect(RegExp(r'^\d+$').hasMatch(n), isTrue, reason: '${h.name}: $n');
        }
      }
    });

    test('numbers are shown the way people read them', () {
      expect(formatPhone('09178427828'), '0917 842 7828');
      expect(formatPhone('0756330312'), '(075) 633 0312');
      expect(formatPhone('911'), '911');
    });
  });

  test('reads an SOS request and its status', () {
    final sos = SosEntry.fromJson({
      'id': 4,
      'status': 'responding',
      'status_label': 'Responding',
      'municipality': 'Bugallon',
      'barangay': 'Poblacion',
      'landmark': 'Beside the chapel',
      'image_url': 'https://example.com/a.jpg',
      'video_url': null,
      'created_at': '2026-10-24T10:00:00+00:00',
      'responded_at': '2026-10-24T10:03:00+00:00',
    });

    expect(sos.isOpen, isTrue);
    expect(sos.hasPhoto, isTrue);
    expect(sos.hasVideo, isFalse);
    expect(sos.respondedAt, isNotNull);
    expect(SosEntry.fromJson({'status': 'resolved'}).isOpen, isFalse);
  });

  test('shows where the SOS is, with or without a typed address', () {
    final typed = SosEntry.fromJson({
      'barangay': 'Poblacion',
      'address': '12 Rizal St., Purok 2',
      'landmark': 'Beside the chapel',
    });
    expect(typed.place, '12 Rizal St., Purok 2, Poblacion · Beside the chapel');

    // Requests sent before the address field existed.
    final older = SosEntry.fromJson({
      'barangay': 'Poblacion',
      'landmark': 'Beside the chapel',
    });
    expect(older.place, 'Poblacion · Beside the chapel');
  });

  testWidgets('the Safety tab lists 911 first and every hotline', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Inactive: no network call in the test.
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SafetyTab(active: false))),
    );

    expect(find.text('Call 911'), findsOneWidget);
    expect(find.text('MDRRMO Bugallon'), findsOneWidget);
    expect(find.text('0917 842 7828'), findsOneWidget);
    expect(find.text('(075) 633 0312'), findsOneWidget);
    expect(find.text('Rural Health Unit · Temporary number'), findsOneWidget);
    expect(find.text('CENPELCO'), findsOneWidget);
    expect(
      find.text('Your past SOS requests are in History.'),
      findsOneWidget,
    );
  });

  testWidgets('an answered SOS says "Someone is Responding"', (tester) async {
    final sos = SosEntry.fromJson({
      'id': 1,
      'status': 'responding',
      'municipality': 'Bugallon',
      'barangay': 'Salomague Sur',
      'landmark': 'bahay',
      'created_at': '2026-10-25T03:57:00+00:00',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SosRequestCard(sos: sos)),
      ),
    );

    expect(find.text('Someone is Responding'), findsOneWidget);
    expect(find.text('Salomague Sur · bahay'), findsOneWidget);
  });

  testWidgets('an open SOS can be marked resolved; a resolved one cannot', (
    tester,
  ) async {
    SosEntry sos(String status) => SosEntry.fromJson({
      'id': 2,
      'status': status,
      'municipality': 'Bugallon',
      'barangay': 'Poblacion',
      'landmark': 'Chapel',
      'created_at': '2026-10-25T03:57:00+00:00',
      'resolved_by_resident': status == 'resolved',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SosRequestCard(sos: sos('sent'))),
      ),
    );
    expect(find.text('Mark as resolved'), findsOneWidget);

    await tester.tap(find.text('Mark as resolved'));
    await tester.pumpAndSettle();
    expect(find.text('Mark as resolved?'), findsOneWidget); // asks first
    await tester.tap(find.text('I still need help'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SosRequestCard(sos: sos('resolved'))),
      ),
    );
    expect(find.text('Mark as resolved'), findsNothing);
    expect(find.text('You marked this request as resolved.'), findsOneWidget);
  });
}
