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
    expect(find.text('Your past SOS requests are in History.'), findsOneWidget);
  });

  testWidgets('an SOS says who is responding, and does not invent one', (
    tester,
  ) async {
    SosEntry sos(Map<String, dynamic> extra) => SosEntry.fromJson({
      'id': 1,
      'status': 'responding',
      'municipality': 'Bugallon',
      'barangay': 'Salomague Sur',
      'landmark': 'bahay',
      'created_at': '2026-10-25T03:57:00+00:00',
      ...extra,
    });

    // The admin took the request on but has not sent anybody yet.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SosRequestCard(sos: sos({}))),
      ),
    );
    expect(find.text('Admin is handling it'), findsOneWidget);
    expect(find.text('Someone is Responding'), findsNothing);
    expect(find.text('Salomague Sur · bahay'), findsOneWidget);

    // A GoBiker is on the way: now it may say so, and name them.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SosRequestCard(
            sos: sos({
              'responder': {'name': 'Juan Dela Cruz', 'barangay': 'Salasa'},
            }),
          ),
        ),
      ),
    );
    expect(find.text('Someone is Responding'), findsOneWidget);
    expect(find.text('Admin is handling it'), findsNothing);
  });

  testWidgets('an answered SOS names the GoBiker who is coming', (
    tester,
  ) async {
    SosEntry sos(Map<String, dynamic> extra) => SosEntry.fromJson({
      'id': 3,
      'status': 'responding',
      'municipality': 'Bugallon',
      'barangay': 'Poblacion',
      'landmark': 'Chapel',
      'created_at': '2026-10-25T03:57:00+00:00',
      ...extra,
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SosRequestCard(
            sos: sos({
              'responder': {
                'name': 'Juan Dela Cruz',
                'barangay': 'Salasa',
                'photo_url': null,
              },
            }),
          ),
        ),
      ),
    );

    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(
      find.text('Juan Dela Cruz is on the way to help you.'),
      findsOneWidget,
    );
    expect(find.text('Responding · GoBiker · Salasa'), findsOneWidget);
    expect(
      find.text('JC'),
      findsOneWidget,
    ); // no photos exist: initials stand in

    // Before the admin assigns anyone there is no name to show.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SosRequestCard(sos: sos({}))),
      ),
    );
    expect(find.text('Juan Dela Cruz'), findsNothing);
    expect(
      find.text('The Go Bike admin has your request and is handling it.'),
      findsOneWidget,
    );
  });

  testWidgets('a resident can cancel their SOS but not mark it resolved', (
    tester,
  ) async {
    SosEntry sos(String status, {bool cancelled = false}) => SosEntry.fromJson({
      'id': 2,
      'status': status,
      'cancelled': cancelled,
      'municipality': 'Bugallon',
      'barangay': 'Poblacion',
      'landmark': 'Chapel',
      'created_at': '2026-10-25T03:57:00+00:00',
      'resolved_by_resident': status == 'resolved',
    });

    // Only the GoBiker sent to help, or the admin, ends an emergency as resolved...
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SosRequestCard(sos: sos('sent'))),
      ),
    );
    expect(find.text('Mark as resolved'), findsNothing);
    // ...but the resident can withdraw it: one button, and only that one.
    expect(find.text('Cancel SOS'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is ButtonStyleButton), findsOneWidget);

    // Requests a resident closed before cancelling existed still read that way.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SosRequestCard(sos: sos('resolved'))),
      ),
    );
    expect(find.text('You marked this request as resolved.'), findsOneWidget);
    expect(find.text('Cancel SOS'), findsNothing);
  });

  test('a cancelled SOS comes as resolved but reads as cancelled', () {
    final sos = SosEntry.fromJson({
      'id': 5,
      'status': 'resolved', // what the server sends, for apps that predate cancelling
      'cancelled': true,
      'status_label': 'Cancelled',
      'resolved_by_resident': true,
      'created_at': '2026-10-25T03:57:00+00:00',
    });

    expect(sos.isOpen, isFalse);
    expect(sos.cancelled, isTrue);
    final style = sosStatusStyle(sos);
    expect(style.label, 'Cancelled');
    expect(style.help, 'You cancelled this request.');
    // A resolved one is still resolved.
    expect(
      sosStatusStyle(SosEntry.fromJson({'status': 'resolved'})).label,
      'Resolved',
    );
  });

  testWidgets('cancelling asks first, and warns when someone is on the way', (
    tester,
  ) async {
    SosEntry sos(Map<String, dynamic> extra) => SosEntry.fromJson({
      'id': 3,
      'status': 'responding',
      'municipality': 'Bugallon',
      'barangay': 'Poblacion',
      'landmark': 'Chapel',
      'created_at': '2026-10-25T03:57:00+00:00',
      ...extra,
    });
    Future<void> open(SosEntry s) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SosRequestCard(sos: s)),
        ),
      );
      await tester.tap(find.text('Cancel SOS'));
      await tester.pumpAndSettle();
    }

    // Nobody sent yet: the admin is the only one told.
    await open(sos({}));
    expect(find.text('Cancel your SOS?'), findsOneWidget);
    expect(
      find.text('The admin will be told you no longer need help.'),
      findsOneWidget,
    );
    // "Keep it" closes the dialog and leaves the request alone (no network call).
    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel your SOS?'), findsNothing);
    expect(find.text('Cancel SOS'), findsOneWidget);

    // Someone is on the way: say they will be told not to come.
    await open(sos({'responder': {'name': 'Maria Santos'}}));
    expect(
      find.text('Maria Santos is on the way. They will be told not to come.'),
      findsOneWidget,
    );
  });
}
