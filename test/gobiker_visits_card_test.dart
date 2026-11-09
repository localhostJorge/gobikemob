import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:go_bike_app/core/appointments.dart';
import 'package:go_bike_app/screens/appointments_screen.dart';

Map<String, dynamic> visit(int id, String status, {String? mobile}) => {
  'id': id,
  'status': status,
  'status_label': status,
  'barangay': 'Poblacion',
  'address': 'Purok 3, near the chapel',
  'preferred_date': '2026-11-20',
  'preferred_window': 'morning',
  'window_label': 'Morning (8 AM – 12 PM)',
  'reason': 'Blood pressure check',
  'created_at': DateTime.now().toUtc().toIso8601String(),
  'updated_at': DateTime.now().toUtc().toIso8601String(),
  'gobiker_id': 7,
  'resident_name': 'Ana Reyes',
  'resident_mobile': mobile ?? '09170001111',
  'resident_age': 61,
};

void main() {
  var mine = <Map<String, dynamic>>[];
  var requests = <Map<String, dynamic>>[];

  Future<http.Response> handle(http.Request r) async {
    final json = {'content-type': 'application/json'};
    final path = r.url.path;
    if (r.method == 'POST' && path.endsWith('/accept')) {
      // The request moves to My visits, as the server does.
      mine = [
        for (final a in requests) {...a, 'status': 'accepted'},
      ];
      requests = [];
      return http.Response('{}', 200, headers: json);
    }
    if (path.endsWith('/gobiker/appointments')) {
      return http.Response(
        jsonEncode({'requests': requests, 'available': [], 'mine': mine}),
        200,
        headers: json,
      );
    }
    if (path.endsWith('/gobiker/patients')) {
      return http.Response(jsonEncode({'patients': []}), 200, headers: json);
    }
    return http.Response('{}', 404, headers: json);
  }

  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    GobikerAppointments.instance.reset();
    mine = [];
    requests = [];
  });

  Future<void> openScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: AppointmentsScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openMyVisits(WidgetTester tester) async {
    await openScreen(tester);
    await tester.tap(find.textContaining('My visits'));
    await tester.pumpAndSettle();
  }

  group('an accepted visit in My visits', () {
    testWidgets('has Record check-up to the right of the number, on one row', (
      tester,
    ) async {
      mine = [visit(1, 'accepted')];
      await http.runWithClient(() async {
        await openMyVisits(tester);

        final call = find.widgetWithText(OutlinedButton, '09170001111');
        final record = find.widgetWithText(FilledButton, 'Record check-up');
        expect(call, findsOneWidget);
        expect(record, findsOneWidget);
        expect(
          tester.getTopLeft(record).dy,
          tester.getTopLeft(call).dy,
          reason: 'same row',
        );
        expect(
          tester.getTopLeft(record).dx,
          greaterThanOrEqualTo(tester.getTopRight(call).dx),
          reason: 'to its right',
        );
        expect(tester.getSize(record).height, greaterThanOrEqualTo(48));
      }, () => MockClient(handle));
    });

    testWidgets('keeps the button on the row, whatever the number', (
      tester,
    ) async {
      mine = [visit(1, 'accepted', mobile: '+63 917 000 1111 ext. 2345678')];
      await http.runWithClient(() async {
        await openMyVisits(tester);

        expect(tester.takeException(), isNull);
        final call = find.widgetWithText(
          OutlinedButton,
          '+63 917 000 1111 ext. 2345678',
        );
        final record = find.widgetWithText(FilledButton, 'Record check-up');
        expect(tester.getTopLeft(record).dy, tester.getTopLeft(call).dy);
        expect(tester.getTopRight(record).dx, lessThanOrEqualTo(360));
      }, () => MockClient(handle));
    });

    testWidgets('opens the check-up from the button, and from the card', (
      tester,
    ) async {
      mine = [visit(1, 'accepted')];
      await http.runWithClient(() async {
        await openMyVisits(tester);

        await tester.tap(find.widgetWithText(FilledButton, 'Record check-up'));
        await tester.pumpAndSettle();
        expect(find.text('Home check-up'), findsOneWidget);
        expect(find.text('Ana Reyes'), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('Home check-up'), findsNothing);

        await tester.tap(find.text('Purok 3, near the chapel, Poblacion'));
        await tester.pumpAndSettle();
        expect(find.text('Home check-up'), findsOneWidget);
      }, () => MockClient(handle));
    });

    testWidgets('has no "Mark visit done" any more', (tester) async {
      mine = [visit(1, 'accepted')];
      await http.runWithClient(() async {
        await openMyVisits(tester);

        expect(find.textContaining('Mark visit done'), findsNothing);
        expect(find.textContaining('Visit Done'), findsNothing);
        expect(find.textContaining('Done without'), findsNothing);
      }, () => MockClient(handle));
    });
  });

  testWidgets('My visits lists only what is still to do', (tester) async {
    mine = [visit(1, 'completed'), visit(2, 'accepted')];
    await http.runWithClient(() async {
      await openMyVisits(tester);

      expect(find.textContaining('My visits (1)'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Record check-up'),
        findsOneWidget,
      );
      expect(find.text('Done'), findsNothing);
    }, () => MockClient(handle));
  });

  testWidgets('says so when there is nothing to do', (tester) async {
    mine = [visit(1, 'completed')];
    await http.runWithClient(() async {
      await openMyVisits(tester);
      expect(find.text('No visits to do.'), findsOneWidget);
    }, () => MockClient(handle));
  });

  testWidgets('accepting a request takes them to My visits', (tester) async {
    requests = [visit(2, 'pending')];
    await http.runWithClient(() async {
      await openScreen(tester);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
      expect(find.text('Record check-up'), findsNothing);

      await tester.tap(find.text('Accept'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      // The visit is there, ready for its check-up, without going to look for it.
      expect(
        find.widgetWithText(FilledButton, 'Record check-up'),
        findsOneWidget,
      );
      expect(find.text('Accept'), findsNothing);
      await tester.pump(const Duration(seconds: 4)); // the toast goes away
    }, () => MockClient(handle));
  });
}
