import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:go_bike_app/core/appointments.dart';
import 'package:go_bike_app/screens/global_state.dart';
import 'package:go_bike_app/screens/visit_checkup_screen.dart';

Map<String, dynamic> visitJson({int? age = 61}) => {
  'id': 4,
  'status': 'accepted',
  'status_label': 'GoBiker assigned',
  'barangay': 'Poblacion',
  'address': 'Purok 3, near the chapel',
  'preferred_date': '2026-11-20',
  'preferred_window': 'afternoon',
  'window_label': 'Afternoon (1 PM – 5 PM)',
  'reason': 'Blood pressure check for my mother',
  'created_at': DateTime.now().toUtc().toIso8601String(),
  'updated_at': DateTime.now().toUtc().toIso8601String(),
  'gobiker_id': 7,
  'resident_name': 'Ana Reyes',
  'resident_mobile': '09170001111',
  'resident_age': age,
};

/// What the server does: records the check-up, or refuses; takes a visit back.
class FakeServer {
  int checkupStatus = 201;
  final List<Map<String, dynamic>> posts = [];

  Future<http.Response> handle(http.Request r) async {
    final json = {'content-type': 'application/json'};
    final path = r.url.path;
    if (r.method == 'POST') {
      posts.add({
        'path': path,
        'body': r.body.isEmpty ? {} : jsonDecode(r.body),
      });
    }
    if (path.endsWith('/checkup')) {
      if (checkupStatus != 201) {
        return http.Response(
          jsonEncode({'message': 'This visit was already finished.'}),
          checkupStatus,
          headers: json,
        );
      }
      return http.Response(
        jsonEncode({
          'message': 'Check-up saved. Visit done.',
          'patient': {
            'id': 77,
            'name': 'Ana Reyes',
            'address': 'Purok 3, near the chapel',
            'contact': '09170001111',
            'age': 61,
            'sys': 128,
            'dia': 84,
            'pulse': 76,
            'resp': 16,
            'temp': 36.7,
            'blood_sugar': null,
            'remarks': null,
            'barangay': 'Poblacion',
            'recorded_at': DateTime.now().toUtc().toIso8601String(),
            'follow_up': null,
          },
        }),
        201,
        headers: json,
      );
    }
    if (path.endsWith('/decline')) {
      return http.Response('{}', 200, headers: json);
    }
    if (path.endsWith('/gobiker/appointments')) {
      return http.Response(
        jsonEncode({'requests': [], 'available': [], 'mine': []}),
        200,
        headers: json,
      );
    }
    return http.Response('{}', 404, headers: json);
  }
}

void main() {
  late FakeServer server;
  VisitOutcome? outcome;

  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    GobikerAppointments.instance.reset();
    globalPatients = [];
    server = FakeServer();
    outcome = null;
  });

  /// The screen, opened from a page the way My visits opens it.
  Future<void> open(WidgetTester tester, {int? age = 61}) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              outcome = await Navigator.push<VisitOutcome>(
                context,
                MaterialPageRoute(
                  builder: (_) => VisitCheckupScreen(
                    appointment: Appointment.fromJson(visitJson(age: age)),
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> run(WidgetTester tester, Future<void> Function() body) =>
      http.runWithClient(body, () => MockClient(server.handle));

  Future<void> fillVitals(WidgetTester tester) async {
    Future<void> type(String hint, String text) =>
        tester.enterText(find.widgetWithText(TextField, hint), text);
    await type('120', '128');
    await type('80', '84');
    await type('72', '76');
    await type('16', '16');
    await type('36.5', '36.7');
  }

  /// The person agreed to the check-up.
  Future<void> tickConsent(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Save check-up'));
    await tester.tap(find.text('Save check-up'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows who is being visited, already filled in from their '
      'request', (tester) async {
    await run(tester, () async {
      await open(tester);

      for (final text in [
        'Ana Reyes',
        'Age 61',
        'Purok 3, near the chapel, Poblacion',
        '09170001111',
        'Blood pressure check for my mother',
        'Filled in from their request. Only the check-up is left.',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.textContaining('Afternoon'), findsOneWidget);
    });
  });

  testWidgets('asks for the vitals only: no name, address, contact or age', (
    tester,
  ) async {
    await run(tester, () async {
      await open(tester);

      for (final label in [
        'Systolic (mmHg)',
        'Diastolic (mmHg)',
        'Pulse (bpm)',
        'Respiration (/min)',
        'Temperature (°C)',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      for (final label in ['Full name', 'Address', 'Contact number', 'Age']) {
        expect(find.text(label), findsNothing, reason: label);
      }
      expect(find.text('PERSONAL DETAILS'), findsNothing);
    });
  });

  testWidgets('asks how old they are only when their account has no '
      'birthdate', (tester) async {
    await run(tester, () async {
      await open(tester, age: null);

      expect(find.text('Age'), findsOneWidget);
      expect(find.text('Their account has no birthdate.'), findsOneWidget);
      expect(find.text('Age 61'), findsNothing);

      // Not saved without it.
      await fillVitals(tester);
      await tickConsent(tester);
      await tapSave(tester);
      expect(find.text('Required'), findsOneWidget);
      expect(server.posts, isEmpty);

      await tester.enterText(find.widgetWithText(TextField, '45'), '47');
      await tapSave(tester);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(server.posts.single['body']['age'], 47);
      await tester.pump(const Duration(seconds: 4));
    });
  });

  testWidgets('does not save with the readings missing', (tester) async {
    await run(tester, () async {
      await open(tester);

      await tapSave(tester);

      expect(find.text('Required'), findsWidgets);
      expect(find.text('Home check-up'), findsOneWidget);
      expect(server.posts, isEmpty);
      await tester.pump(const Duration(seconds: 4)); // the toast
    });
  });

  testWidgets('asks first, then saves only the readings, and finishes the '
      'visit', (tester) async {
    await run(tester, () async {
      await open(tester);
      await fillVitals(tester);
      await tester.enterText(
        find.widgetWithText(TextField, '95'),
        '105',
      ); // blood sugar
      await tickConsent(tester);
      await tapSave(tester);

      // Asked first: nothing is sent yet.
      expect(find.text('Save this check-up?'), findsOneWidget);
      expect(server.posts, isEmpty);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final post = server.posts.single;
      expect(post['path'], endsWith('/gobiker/appointments/4/checkup'));
      expect(post['body'], {
        'sys': '128',
        'dia': '84',
        'pulse': '76',
        'resp': '16',
        'temp': '36.7',
        'blood_sugar': '105',
        'remarks': null,
        'consent': true,
      });

      // Back on the page it was opened from, which is told what happened; the record is kept.
      expect(find.text('Home check-up'), findsNothing);
      expect(outcome, VisitOutcome.recorded);
      expect(globalPatients.single['id'], '77');
      expect(globalPatients.single['name'], 'Ana Reyes');
    });
  });

  testWidgets('does not save until the person agreed to the check-up', (
    tester,
  ) async {
    await run(tester, () async {
      await open(tester);
      await fillVitals(tester);
      await tapSave(tester);

      expect(
        find.text('Ask for their consent before saving the check-up.'),
        findsOneWidget,
      );
      expect(find.text('Save this check-up?'), findsNothing);
      expect(server.posts, isEmpty);

      await tickConsent(tester);
      await tapSave(tester);
      expect(find.text('Save this check-up?'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4)); // the toast
    });
  });

  testWidgets('keeps everything typed when the server says no', (tester) async {
    server.checkupStatus = 422;
    await run(tester, () async {
      await open(tester);
      await fillVitals(tester);
      await tickConsent(tester);
      await tapSave(tester);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Home check-up'), findsOneWidget);
      expect(find.text('This visit was already finished.'), findsOneWidget);
      expect(find.text('128'), findsOneWidget);
      expect(globalPatients, isEmpty);
      expect(outcome, isNull);
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group("Couldn't do this visit", () {
    testWidgets('asks first, and Back changes nothing', (tester) async {
      await run(tester, () async {
        await open(tester);

        await tester.ensureVisible(find.text("Couldn't do this visit"));
        await tester.tap(find.text("Couldn't do this visit"));
        await tester.pumpAndSettle();
        expect(find.text("Can't do this visit?"), findsOneWidget);

        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();
        expect(find.text("Can't do this visit?"), findsNothing);
        expect(find.text('Home check-up'), findsOneWidget);
        expect(server.posts, isEmpty);
      });
    });

    testWidgets('tells the resident, with the reason, and saves no check-up', (
      tester,
    ) async {
      await run(tester, () async {
        await open(tester);

        await tester.ensureVisible(find.text("Couldn't do this visit"));
        await tester.tap(find.text("Couldn't do this visit"));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'e.g. I am out of town that day'),
          'My bike broke down.',
        );
        await tester.tap(find.text("Can't do it"));
        await tester.pumpAndSettle();

        final post = server.posts.firstWhere(
          (p) => '${p['path']}'.endsWith('/decline'),
        );
        expect(post['path'], endsWith('/gobiker/appointments/4/decline'));
        expect(post['body'], {'note': 'My bike broke down.'});
        expect(
          server.posts.any((p) => '${p['path']}'.endsWith('/checkup')),
          isFalse,
        );
        expect(find.text('Home check-up'), findsNothing);
        expect(outcome, VisitOutcome.withdrawn);
        expect(globalPatients, isEmpty);
      });
    });
  });
}
