import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:go_bike_app/core/appointments.dart';
import 'package:go_bike_app/core/gobiker_history.dart';
import 'package:go_bike_app/core/ronda_store.dart';
import 'package:go_bike_app/screens/dashboard_screen.dart';
import 'package:go_bike_app/screens/global_state.dart';
import 'package:go_bike_app/screens/gobiker_history_screen.dart';

DateTime ago({int days = 0, int hours = 0}) =>
    DateTime.now().subtract(Duration(days: days, hours: hours));

Map<String, dynamic> ronda({
  String barangay = 'Poblacion',
  DateTime? ended,
  int patients = 2,
  double km = 3.4,
}) {
  final end = ended ?? ago(hours: 2);
  return {
    'barangay': barangay,
    'date': DateFormat('MMMM d, yyyy')
        .format(end), // the format the dashboard compares
    'startTime': '08:00 AM',
    'endTime': '10:15 AM',
    'endDateTime': end,
    'patientsCount': patients,
    'distance': km,
  };
}

Map<String, dynamic> visitJson(
  int id,
  String status, {
  DateTime? changed,
  String? note,
  int? patientId,
}) => {
  'id': id,
  'status': status,
  'status_label': status,
  'barangay': 'Poblacion',
  'address': 'Purok 3, near the chapel',
  'preferred_date': '2026-11-20',
  'preferred_window': 'morning',
  'window_label': 'Morning (8 AM – 12 PM)',
  'reason': 'Blood pressure check for my mother',
  'created_at': (changed ?? ago(hours: 5)).toUtc().toIso8601String(),
  'updated_at': (changed ?? ago(hours: 3)).toUtc().toIso8601String(),
  'completed_at': status == 'completed'
      ? (changed ?? ago(hours: 3)).toUtc().toIso8601String()
      : null,
  'decline_note': note,
  'gobiker_id': 7,
  'resident_name': 'Ana Reyes',
  'resident_mobile': '09170001111',
  'patient_id': patientId,
};

Map<String, dynamic> sosJson(
  int id, {
  bool cancelled = false,
  DateTime? ended,
}) => {
  'id': id,
  'status': 'resolved',
  'cancelled': cancelled,
  'resident_name': 'Ben Cruz',
  'barangay': 'Poblacion',
  'address': '12 Rizal St.',
  'landmark': 'Chapel',
  'description': 'Fell at home',
  'created_at': (ended ?? ago(hours: 6)).toUtc().toIso8601String(),
  'responded_at': (ended ?? ago(hours: 5)).toUtc().toIso8601String(),
  'resolved_at': (ended ?? ago(hours: 4)).toUtc().toIso8601String(),
};

Map<String, dynamic> patientJson(int id, {DateTime? at}) => {
  'id': id,
  'name': 'Lola Nena',
  'address': 'Purok 1',
  'contact': '09180002222',
  'age': 71,
  'sys': 130,
  'dia': 85,
  'pulse': 78,
  'resp': 18,
  'temp': 36.6,
  'barangay': 'Poblacion',
  'recorded_at': (at ?? ago(hours: 1)).toUtc().toIso8601String(),
};

/// A server for the History screen: what it has, and what to do when asked.
class FakeServer {
  List<Map<String, dynamic>> visits = [];
  List<Map<String, dynamic>> sos = [];
  List<Map<String, dynamic>> patients = [];
  int historyStatus = 200;
  int patientsStatus = 200;
  int historyCalls = 0;

  Future<http.Response> handle(http.Request r) async {
    final path = r.url.path;
    Map<String, String> json = {'content-type': 'application/json'};
    if (path.endsWith('/gobiker/history')) {
      historyCalls++;
      if (historyStatus != 200) {
        return http.Response(
          jsonEncode({'message': 'History is down.'}),
          historyStatus,
          headers: json,
        );
      }
      return http.Response(
        jsonEncode({'appointments': visits, 'sos': sos}),
        200,
        headers: json,
      );
    }
    if (path.endsWith('/gobiker/patients')) {
      if (patientsStatus != 200) {
        return http.Response(
          jsonEncode({'message': 'Patients are down.'}),
          patientsStatus,
          headers: json,
        );
      }
      return http.Response(
        jsonEncode({'patients': patients}),
        200,
        headers: json,
      );
    }
    return http.Response('{}', 404, headers: json);
  }
}

void main() {
  late FakeServer server;

  Future<T> inServer<T>(Future<T> Function() body) =>
      http.runWithClient(body, () => MockClient(server.handle));

  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    server = FakeServer();
    GobikerHistory.instance.reset();
    GobikerAppointments.instance.reset();
    globalRondas = [];
    globalPatients = [];
  });

  group('rondas kept on the phone', () {
    test('come back as they were saved, oldest first', () async {
      await RondaStore.addFinished(
        5,
        ronda(barangay: 'Asinan', ended: ago(days: 2), patients: 1, km: 1.5),
      );
      await RondaStore.addFinished(
        5,
        ronda(barangay: 'Poblacion', patients: 4, km: 6.25),
      );

      final saved = await RondaStore.loadFinished(5);

      expect(saved.map((r) => r['barangay']), ['Asinan', 'Poblacion']);
      expect(saved.last['patientsCount'], 4);
      expect(saved.last['distance'], 6.25);
      expect(saved.last['endDateTime'], isA<DateTime>());
      expect(saved.last['startTime'], '08:00 AM');
    });

    test('belong to one account each', () async {
      await RondaStore.addFinished(1, ronda(barangay: 'Asinan'));
      await RondaStore.addFinished(2, ronda(barangay: 'Polong'));

      expect((await RondaStore.loadFinished(1)).single['barangay'], 'Asinan');
      expect((await RondaStore.loadFinished(2)).single['barangay'], 'Polong');
      expect(await RondaStore.loadFinished(3), isEmpty);
    });

    test('keep only the newest 200', () async {
      for (var i = 1; i <= RondaStore.maxFinished + 5; i++) {
        await RondaStore.addFinished(1, ronda(barangay: 'B$i'));
      }

      final saved = await RondaStore.loadFinished(1);
      expect(saved, hasLength(RondaStore.maxFinished));
      expect(saved.first['barangay'], 'B6');
      expect(saved.last['barangay'], 'B${RondaStore.maxFinished + 5}');
    });

    test('are not lost to damaged saved data', () async {
      SharedPreferences.setMockInitialValues({
        'ronda.finished.1': 'not json at all',
      });
      SharedPreferences.resetStatic();
      expect(await RondaStore.loadFinished(1), isEmpty);

      SharedPreferences.resetStatic();
      SharedPreferences.setMockInitialValues({
        'ronda.finished.1': jsonEncode([
          {'barangay': 'No date given'},
          {
            'barangay': 'Fine',
            'endDateTime': ago(hours: 1).toIso8601String(),
            'patientsCount': 1,
            'distance': 2,
          },
        ]),
      });
      final saved = await RondaStore.loadFinished(1);
      expect(saved.map((r) => r['barangay']), [
        'Fine',
      ], reason: 'one that cannot be placed in time is skipped');
      expect(saved.single['distance'], 2.0);
    });
  });

  group('the history', () {
    test(
      'puts rondas, check-ups, home visits and SOS in one list, newest first',
      () async {
        await RondaStore.addFinished(0, ronda(ended: ago(hours: 2)));
        server
          ..patients = [patientJson(1, at: ago(hours: 1))]
          ..visits = [visitJson(10, 'completed', changed: ago(hours: 3))]
          ..sos = [sosJson(20, ended: ago(hours: 4))];

        await inServer(GobikerHistory.instance.load);
        final entries = GobikerHistory.instance.entries();

        expect(entries.map((e) => e.kind), [
          HistoryKind.checkup, // 1 hour ago
          HistoryKind.ronda, // 2
          HistoryKind.visit, // 3
          HistoryKind.sos, // 4
        ]);
        expect(entries[0].title, 'Check-up · Lola Nena');
        expect(entries[1].title, 'Ronda · Brgy. Poblacion');
        expect(
          entries[1].subtitle,
          '08:00 AM - 10:15 AM · 2 patients · 3.4 km',
        );
        expect(entries[2].title, 'Home visit · Ana Reyes');
        expect(entries[3].title, 'SOS · Ben Cruz');
      },
    );

    test('says how each home visit and SOS ended', () async {
      server
        ..visits = [
          visitJson(1, 'completed', changed: ago(hours: 1)),
          visitJson(2, 'declined', changed: ago(hours: 2)),
          visitJson(3, 'cancelled', changed: ago(hours: 3)),
        ]
        ..sos = [
          sosJson(4, ended: ago(hours: 4)),
          sosJson(5, cancelled: true, ended: ago(hours: 5)),
        ];

      await inServer(GobikerHistory.instance.load);

      expect(GobikerHistory.instance.entries().map((e) => e.status), [
        'Done',
        'Declined by you',
        'Cancelled by the resident',
        'Resolved',
        'Cancelled by the resident',
      ]);
    });

    test(
      'Clear hides what is there, keeps what comes later, and is remembered',
      () async {
        server
          ..visits = [visitJson(1, 'completed', changed: ago(hours: 3))]
          ..sos = [sosJson(2, ended: ago(hours: 4))];
        await RondaStore.addFinished(0, ronda(ended: ago(hours: 5)));
        await inServer(GobikerHistory.instance.load);
        expect(GobikerHistory.instance.entries(), hasLength(3));

        await GobikerHistory.instance.clear();
        expect(GobikerHistory.instance.entries(), isEmpty);

        // Something finished after the Clear shows; the old ones stay hidden.
        server.visits = [
          visitJson(1, 'completed', changed: ago(hours: 3)),
          visitJson(
            9,
            'completed',
            changed: DateTime.now().add(const Duration(minutes: 5)),
          ),
        ];
        await inServer(GobikerHistory.instance.load);
        expect(GobikerHistory.instance.entries(), hasLength(1));
        expect(GobikerHistory.instance.entries().single.visit!.id, 9);

        // Closing the app and opening it again does not bring them back.
        GobikerHistory.instance.reset();
        await inServer(GobikerHistory.instance.load);
        expect(GobikerHistory.instance.entries(), hasLength(1));
      },
    );

    test('Clear is per account', () async {
      server.visits = [visitJson(1, 'completed')];
      await inServer(GobikerHistory.instance.load);
      await GobikerHistory.instance.clear();

      SharedPreferences.resetStatic();
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where((k) => k.startsWith('gobiker.history.cleared.')),
        hasLength(1),
      );
    });

    test(
      'shows what loaded when one part fails, and an error only when both do',
      () async {
        server
          ..visits = [visitJson(1, 'completed')]
          ..patientsStatus = 500;
        await inServer(GobikerHistory.instance.load);
        expect(GobikerHistory.instance.entries(), hasLength(1));
        expect(GobikerHistory.instance.partial, isTrue);
        expect(GobikerHistory.instance.error, isNull);

        // Both down on a later refresh: what is already shown stays, marked as out of date.
        server.historyStatus = 500;
        await inServer(GobikerHistory.instance.load);
        expect(GobikerHistory.instance.entries(), hasLength(1));
        expect(GobikerHistory.instance.partial, isTrue);
        expect(GobikerHistory.instance.error, isNull);
      },
    );

    test(
      'is an error, not an empty list, when the first load fails completely',
      () async {
        server
          ..historyStatus = 500
          ..patientsStatus = 500;
        await inServer(GobikerHistory.instance.load);

        expect(GobikerHistory.instance.loaded, isFalse);
        expect(GobikerHistory.instance.error, isNotNull);
        expect(GobikerHistory.instance.entries(), isEmpty);

        server
          ..historyStatus = 200
          ..patientsStatus = 200;
        await inServer(GobikerHistory.instance.load);
        expect(GobikerHistory.instance.loaded, isTrue);
        expect(GobikerHistory.instance.error, isNull);
      },
    );

    test('is empty for a GoBiker with nothing finished', () async {
      await inServer(GobikerHistory.instance.load);

      expect(GobikerHistory.instance.entries(), isEmpty);
      expect(GobikerHistory.instance.loaded, isTrue);
      expect(GobikerHistory.instance.error, isNull);
    });
  });

  group('the History screen', () {
    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await inServer(() async {
        await tester.pumpWidget(
          const MaterialApp(home: GobikerHistoryScreen()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      });
    }

    void fill() {
      server
        ..patients = [patientJson(1, at: ago(hours: 1))]
        ..visits = [
          visitJson(
            10,
            'declined',
            changed: ago(hours: 3),
            note: 'I am away that week.',
          ),
          visitJson(11, 'completed', changed: ago(hours: 3, days: 1)),
        ]
        ..sos = [sosJson(20, ended: ago(hours: 4))];
    }

    testWidgets(
      'lists everything by day, and each filter keeps only its kind',
      (tester) async {
        fill();
        await RondaStore.addFinished(0, ronda(ended: ago(hours: 2)));
        await open(tester);

        expect(find.text('Today'), findsOneWidget);
        expect(find.text('Yesterday'), findsOneWidget);
        expect(find.text('Check-up · Lola Nena'), findsOneWidget);
        expect(find.text('Ronda · Brgy. Poblacion'), findsOneWidget);
        expect(find.text('SOS · Ben Cruz'), findsOneWidget);
        expect(find.text('Home visit · Ana Reyes'), findsNWidgets(2));

        await tester.tap(find.widgetWithText(ChoiceChip, 'Rondas'));
        await tester.pump();
        expect(find.text('Ronda · Brgy. Poblacion'), findsOneWidget);
        expect(find.text('SOS · Ben Cruz'), findsNothing);

        await tester.tap(find.widgetWithText(ChoiceChip, 'SOS'));
        await tester.pump();
        expect(find.text('SOS · Ben Cruz'), findsOneWidget);
        expect(find.text('Home visit · Ana Reyes'), findsNothing);

        await tester.tap(find.widgetWithText(ChoiceChip, 'Check-ups'));
        await tester.pump();
        expect(find.text('Check-up · Lola Nena'), findsOneWidget);
      },
    );

    testWidgets(
      'a home visit opens its details, with the message the GoBiker sent',
      (tester) async {
        fill();
        await open(tester);

        await tester.tap(find.widgetWithText(ChoiceChip, 'Home visits'));
        await tester.pump();
        await tester.tap(find.text('Declined by you'));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Home visit'), findsOneWidget); // the page title
        // The list is still underneath: look only inside the details page.
        final page = find.byType(GobikerHistoryDetailsScreen);
        Finder onPage(String text) =>
            find.descendant(of: page, matching: find.text(text));
        expect(onPage('Ana Reyes'), findsOneWidget);
        expect(onPage('Purok 3, near the chapel, Poblacion'), findsOneWidget);
        expect(onPage('Blood pressure check for my mother'), findsOneWidget);
        expect(onPage('Your message'), findsOneWidget);
        expect(onPage('I am away that week.'), findsOneWidget);
      },
    );

    testWidgets('an SOS and a ronda open their details', (tester) async {
      fill();
      await RondaStore.addFinished(
        0,
        ronda(ended: ago(hours: 2), patients: 3, km: 7.0),
      );
      await open(tester);

      await tester.tap(find.text('SOS · Ben Cruz'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Emergency'), findsOneWidget);
      final sosPage = find.byType(GobikerHistoryDetailsScreen);
      expect(
        find.descendant(of: sosPage, matching: find.text('Fell at home')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: sosPage,
          matching: find.text('12 Rizal St., Poblacion · Chapel'),
        ),
        findsOneWidget,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ronda · Brgy. Poblacion'));
      await tester.pump();
      await tester.pumpAndSettle();
      final rondaPage = find.byType(GobikerHistoryDetailsScreen);
      expect(
        find.descendant(of: rondaPage, matching: find.text('7.0 km')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: rondaPage, matching: find.text('3')),
        findsOneWidget,
      );
    });

    testWidgets('Clear asks first, then empties the list and says so', (
      tester,
    ) async {
      fill();
      await open(tester);

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(find.text('Clear history?'), findsOneWidget);
      expect(find.textContaining('Nothing is deleted'), findsOneWidget);

      // Cancelling leaves everything.
      await tester.tapAt(const Offset(5, 5)); // the barrier
      await tester.pumpAndSettle();
      expect(find.text('SOS · Ben Cruz'), findsOneWidget);

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Clear').last);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('SOS · Ben Cruz'), findsNothing);
      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(find.text('History cleared.'), findsOneWidget);
      expect(find.text('Clear'), findsNothing, reason: 'nothing left to clear');
    });

    testWidgets('says so when there is nothing yet, with no Clear button', (
      tester,
    ) async {
      await open(tester);

      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(find.text('Clear'), findsNothing);
    });

    testWidgets('offers Try again when nothing could be loaded', (
      tester,
    ) async {
      server
        ..historyStatus = 500
        ..patientsStatus = 500;
      await open(tester);

      expect(find.text("Couldn't load your history"), findsOneWidget);

      server
        ..historyStatus = 200
        ..patientsStatus = 200
        ..visits = [visitJson(1, 'completed')];
      await inServer(() async {
        await tester.tap(find.text('Try again'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      });

      expect(find.text('Home visit · Ana Reyes'), findsOneWidget);
    });

    testWidgets('says when part of it could not be loaded', (tester) async {
      server
        ..visits = [visitJson(1, 'completed')]
        ..patientsStatus = 500;
      await open(tester);

      expect(find.text('Home visit · Ana Reyes'), findsOneWidget);
      expect(
        find.textContaining('Some of your history could not be loaded'),
        findsOneWidget,
      );
    });
  });

  group('the GoBiker home screen', () {
    Future<void> openHome(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await inServer(() async {
        await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
        await tester.pump(const Duration(milliseconds: 800));
      });
    }

    Appointment done(int id, {DateTime? at, int? patientId}) {
      final when = at ?? DateTime.now();
      return Appointment.fromJson(
        visitJson(id, 'completed', changed: when, patientId: patientId),
      );
    }

    /// The number shown above "Visited" in Today's summary, read from the strip's own label.
    String visited(WidgetTester tester) {
      final label = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .map((w) => w.properties.label)
          .whereType<String>()
          .firstWhere((l) => l.startsWith('Visited: '));
      return label.substring('Visited: '.length);
    }

    testWidgets(
      'has Home, Map, History and Profile in the bar, and History opens',
      (tester) async {
        await openHome(tester);

        for (final label in ['Home', 'Map', 'History', 'Profile']) {
          expect(find.text(label), findsWidgets, reason: label);
        }

        await inServer(() async {
          await tester.tap(find.text('History').last);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
        });
        expect(find.byType(GobikerHistoryScreen), findsOneWidget);
      },
    );

    testWidgets(
      'no longer has a Ronda History button, and Message Admin takes the width',
      (tester) async {
        await openHome(tester);

        expect(find.text('Ronda History'), findsNothing);
        final button = find.widgetWithText(OutlinedButton, 'Message Admin');
        expect(button, findsOneWidget);
        // The width of the page less its two 16 dp margins.
        expect(tester.getSize(button).width, closeTo(1080 / 2.5 - 32, 1));
      },
    );

    testWidgets('counts a home visit marked done today under Visited', (
      tester,
    ) async {
      GobikerAppointments.instance.mine = [done(1)];
      await openHome(tester);

      expect(visited(tester), '1');
    });

    testWidgets(
      'adds it to the patients of today\'s rondas, which were saved on the phone',
      (tester) async {
        // Finished earlier today, and the app has been closed and opened again since.
        await RondaStore.addFinished(
          0,
          ronda(ended: DateTime.now(), patients: 2),
        );
        GobikerAppointments.instance.mine = [done(1), done(2)];
        await openHome(tester);

        expect(visited(tester), '4');
      },
    );

    testWidgets('does not count yesterday\'s visit, or one that is not done', (
      tester,
    ) async {
      GobikerAppointments.instance.mine = [
        done(1, at: ago(days: 1)),
        Appointment.fromJson(visitJson(2, 'accepted')),
      ];
      await openHome(tester);

      expect(visited(tester), '0');
    });

    testWidgets(
      'does not count a visit twice when a check-up is linked to it',
      (tester) async {
        GobikerAppointments.instance.mine = [done(1, patientId: 55), done(2)];
        await openHome(tester);

        expect(
          visited(tester),
          '1',
          reason:
              'the linked one is that check-up, counted where it was recorded',
        );
      },
    );
  });
}
