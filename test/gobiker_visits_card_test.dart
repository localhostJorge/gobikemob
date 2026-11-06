import 'dart:async';
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
};

void main() {
  late List<Map<String, dynamic>> mine;
  var requests = <Map<String, dynamic>>[];
  Completer<http.Response>? completing;

  Future<http.Response> handle(http.Request r) async {
    final json = {'content-type': 'application/json'};
    if (r.method == 'POST' && r.url.path.endsWith('/complete')) {
      // Held until the test lets go, to look at the card while it is saving.
      final done = completing = Completer<http.Response>();
      return done.future;
    }
    if (r.url.path.endsWith('/gobiker/appointments')) {
      return http.Response(
        jsonEncode({'requests': requests, 'available': [], 'mine': mine}),
        200,
        headers: json,
      );
    }
    if (r.url.path.endsWith('/gobiker/patients')) {
      return http.Response(jsonEncode({'patients': []}), 200, headers: json);
    }
    return http.Response('{}', 404, headers: json);
  }

  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    GobikerAppointments.instance.reset();
    completing = null;
    requests = [];
  });

  Future<void> openMyVisits(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: AppointmentsScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.textContaining('My visits'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Mark visit done sits to the right of the number, on the same row',
    (tester) async {
      mine = [visit(1, 'accepted')];
      await http.runWithClient(() async {
        await openMyVisits(tester);

        final call = find.widgetWithText(OutlinedButton, '09170001111');
        final done = find.widgetWithText(FilledButton, 'Mark visit done');
        expect(call, findsOneWidget);
        expect(done, findsOneWidget);
        expect(
          tester.getTopLeft(done).dy,
          tester.getTopLeft(call).dy,
          reason: 'same row',
        );
        expect(
          tester.getTopLeft(done).dx,
          greaterThanOrEqualTo(tester.getTopRight(call).dx),
          reason: 'to its right',
        );
        expect(tester.getSize(done).height, greaterThanOrEqualTo(48));
      }, () => MockClient(handle));
    },
  );

  testWidgets('a long number never pushes the button off the row', (
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
      final done = find.widgetWithText(FilledButton, 'Mark visit done');
      expect(tester.getTopLeft(done).dy, tester.getTopLeft(call).dy);
      expect(tester.getTopRight(done).dx, lessThanOrEqualTo(360));
    }, () => MockClient(handle));
  });

  testWidgets(
    'the button stays where it is, with the same label, while saving',
    (tester) async {
      mine = [visit(1, 'accepted')];
      await http.runWithClient(() async {
        await openMyVisits(tester);

        final done = find.widgetWithText(FilledButton, 'Mark visit done');
        final call = find.widgetWithText(OutlinedButton, '09170001111');
        final doneAt = tester.getRect(done);
        final callAt = tester.getRect(call);

        await tester.tap(done);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Done without a check-up'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Saving: disabled, a spinner on it, and not an inch moved.
        expect(completing, isNotNull);
        expect(find.text('Saving…'), findsNothing);
        expect(tester.widget<FilledButton>(done).onPressed, isNull);
        expect(
          find.descendant(
            of: done,
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );
        expect(tester.getRect(done), doneAt);
        expect(tester.getRect(call), callAt);

        completing!.complete(
          http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 4)); // the toast goes away
      }, () => MockClient(handle));
    },
  );

  testWidgets(
    'a request to answer keeps Accept and Decline, and no Mark done',
    (tester) async {
      mine = [];
      await http.runWithClient(() async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        requests = [visit(2, 'pending')];
        await tester.pumpWidget(const MaterialApp(home: AppointmentsScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Accept'), findsOneWidget);
        expect(find.text('Decline'), findsOneWidget);
        expect(find.text('Mark visit done'), findsNothing);
      }, () => MockClient(handle));
    },
  );
}
