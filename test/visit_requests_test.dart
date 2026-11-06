import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:go_bike_app/core/appointments.dart';
import 'package:go_bike_app/core/auth_service.dart';
import 'package:go_bike_app/core/resident_sos.dart';
import 'package:go_bike_app/screens/patient/appointment_screen.dart';
import 'package:go_bike_app/screens/patient/gobiker_picker.dart';
import 'package:go_bike_app/screens/patient/history_screen.dart';
import 'package:go_bike_app/screens/patient/patient_store.dart';
import 'package:go_bike_app/screens/patient/resident_dashboard_screen.dart';
import 'package:go_bike_app/screens/patient/visit_request_screen.dart';

const _labels = {
  'pending': 'Waiting for the GoBiker to accept',
  'accepted': 'GoBiker assigned',
  'completed': 'Visit done',
  'declined': 'Declined',
  'cancelled': 'Cancelled',
};

Appointment visit({
  int id = 1,
  String status = 'pending',
  int? gobikerId = 7,
  String gobiker = 'Maria Santos',
  String? note,
  DateTime? date,
  String barangay = 'Poblacion',
  DateTime? changed,
}) {
  final day = date ?? DateTime.now().add(const Duration(days: 3));
  return Appointment.fromJson({
    'id': id,
    'status': status,
    'status_label': _labels[status],
    'barangay': barangay,
    'address': 'Purok 3, near the chapel',
    'preferred_date': day.toIso8601String().substring(0, 10),
    'preferred_window': 'morning',
    'window_label': 'Morning (8 AM – 12 PM)',
    'reason': 'Blood pressure check for my mother',
    'created_at': (changed ?? DateTime.now()).toIso8601String(),
    'updated_at': (changed ?? DateTime.now()).toIso8601String(),
    'gobiker_id': gobikerId,
    'gobiker_name': gobikerId == null ? null : gobiker,
    'gobiker_barangay': gobikerId == null ? null : 'Poblacion',
    'decline_note': note,
  });
}

/// A request the way the server sends it, so a reload gives the same one back.
Map<String, dynamic> asJson(Appointment a) => {
  'id': a.id,
  'status': a.status,
  'status_label': a.statusLabel,
  'barangay': a.barangay,
  'address': a.address,
  'preferred_date': a.preferredDate.toIso8601String().substring(0, 10),
  'preferred_window': a.window,
  'window_label': a.windowLabel,
  'reason': a.reason,
  'created_at': a.createdAt.toUtc().toIso8601String(),
  'updated_at': a.updatedAt?.toUtc().toIso8601String(),
  'gobiker_id': a.gobikerId,
  'gobiker_name': a.gobikerName,
  'gobiker_barangay': a.gobikerBarangay,
  'decline_note': a.declineNote,
};

GobikerOption gobiker(int id, String name, [String barangay = 'Poblacion']) =>
    GobikerOption(id: id, name: name, barangay: barangay, visitsDone: id);

/// A server that answers the visit list and records what was sent to it.
class FakeServer {
  List<Appointment> appointments = [];
  final posted = <Map<String, dynamic>>[];
  int postStatus = 201;
  String postMessage = 'Visit requested.';

  Future<http.Response> handle(http.Request r) async {
    final path = r.url.path;
    if (r.method == 'POST' && path.endsWith('/resident/appointments')) {
      posted.add(jsonDecode(r.body) as Map<String, dynamic>);
      return http.Response(
        jsonEncode({'message': postMessage}),
        postStatus,
        headers: {'content-type': 'application/json'},
      );
    }
    if (r.method == 'GET' && path.endsWith('/resident/appointments')) {
      return http.Response(
        jsonEncode({'appointments': appointments.map(asJson).toList()}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response('{}', 404);
  }
}

Future<void> Function() _withServer(
  FakeServer server,
  Future<void> Function() body,
) =>
    () => http.runWithClient(body, () => MockClient(server.handle));

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
  late FakeServer server;

  setUp(() async {
    // The store keeps the saved-data object it first got, so start every test from a fresh
    // one: otherwise what one test marked as seen or hidden is still there for the next.
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    PatientStore.instance.debugForgetPreferences();
    server = FakeServer();
    ResidentAppointments.instance.reset();
    ResidentSos.instance.reset();
    await PatientStore.instance.load();
  });

  tearDown(() {
    PatientStore.instance.clearSession();
    ResidentAppointments.instance.reset();
  });

  void setRequests(List<Appointment> list) {
    server.appointments = list;
    ResidentAppointments.instance
      ..appointments = list
      ..loaded = true;
  }

  group('finding a GoBiker by name', () {
    final people = [
      gobiker(1, 'Maria Santos'),
      gobiker(2, 'José Peña'),
      gobiker(3, 'Ana Reyes'),
    ];

    test('matches words in any order, ignoring case and accents', () {
      expect(filterGobikers(people, 'santos maria').map((g) => g.id), [1]);
      expect(filterGobikers(people, 'PENA').map((g) => g.id), [2]);
      expect(filterGobikers(people, 'jose').map((g) => g.id), [2]);
      expect(filterGobikers(people, 'ana r').map((g) => g.id), [3]);
    });

    test(
      'an empty or blank search keeps everyone, a stranger finds no one',
      () {
        expect(filterGobikers(people, ''), people);
        expect(filterGobikers(people, '   '), people);
        expect(filterGobikers(people, 'Zed'), isEmpty);
      },
    );

    test('plain text drops accents and extra spaces', () {
      expect(plainText('  Peña   Niño '), 'pena nino');
    });
  });

  group('the GoBiker list', () {
    late List<String?> asked;

    Future<({List<GobikerOption> gobikers, String? error})> loader(
      String? barangay,
    ) async {
      asked.add(barangay);
      return (
        gobikers: barangay == 'Polong'
            ? [gobiker(20, 'Pia Tan', 'Polong')]
            : [
                gobiker(7, 'Maria Santos'),
                gobiker(8, 'Jose Lim'),
                gobiker(9, 'Rico Dela'),
              ],
        error: null,
      );
    }

    setUp(() => asked = []);

    Future<List<GobikerOption>> show(
      WidgetTester tester, {
      Set<int> exclude = const {},
      Set<int> disabled = const {},
    }) async {
      final picked = <GobikerOption>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GobikerPickerBody(
                startBarangay: 'Poblacion',
                scrollable: false,
                loader: loader,
                excludeIds: exclude,
                disabledIds: disabled,
                onPick: picked.add,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return picked;
    }

    testWidgets('lists the barangay, and narrows as the name is typed', (
      tester,
    ) async {
      await show(tester);
      expect(find.text('Maria Santos'), findsOneWidget);
      expect(find.text('Jose Lim'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'lim');
      await tester.pump();

      expect(find.text('Jose Lim'), findsOneWidget);
      expect(find.text('Maria Santos'), findsNothing);
      expect(find.text('Rico Dela'), findsNothing);
    });

    testWidgets('says when nobody matches, and Clear brings everyone back', (
      tester,
    ) async {
      await show(tester);
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();

      expect(find.text('No GoBiker matches "zzz"'), findsOneWidget);
      expect(find.text('Maria Santos'), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Clear search'));
      await tester.pump();
      expect(find.text('Maria Santos'), findsOneWidget);
    });

    testWidgets('the clear button in the field empties the search', (
      tester,
    ) async {
      await show(tester);
      await tester.enterText(find.byType(TextField), 'rico');
      await tester.pump();
      expect(find.text('Jose Lim'), findsNothing);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();
      expect(find.text('Jose Lim'), findsOneWidget);
    });

    testWidgets(
      'leaves out an excluded GoBiker and cannot pick a disabled one',
      (tester) async {
        final picked = await show(tester, exclude: {7}, disabled: {8});

        expect(find.text('Maria Santos'), findsNothing);
        expect(
          find.text('Already asked, waiting for their answer'),
          findsOneWidget,
        );

        await tester.tap(find.text('Jose Lim'));
        await tester.pump();
        expect(
          picked,
          isEmpty,
          reason: 'already has a request from this person',
        );

        await tester.tap(find.text('Rico Dela'));
        await tester.pump();
        expect(picked.map((g) => g.id), [9]);
      },
    );

    testWidgets('looks in another barangay when asked', (tester) async {
      await show(tester);
      expect(asked, ['Poblacion']);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Polong').last);
      await tester.pumpAndSettle();

      expect(asked, ['Poblacion', 'Polong']);
      expect(find.text('Pia Tan'), findsOneWidget);
      expect(find.text('Maria Santos'), findsNothing);
    });
  });

  group('the Home visit screen', () {
    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: AppointmentScreen()));
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('opens the request form even with a request still waiting', (
      tester,
    ) async {
      setRequests([visit(status: 'pending')]);
      await open(tester);

      expect(find.text('Request a home check-up'), findsOneWidget);
      expect(find.textContaining('Waiting for'), findsNothing);
      expect(
        find.text('You have 1 open request. See their answers in History.'),
        findsOneWidget,
      );
      expect(canPress(tester, 'Request visit'), isTrue);
    });

    testWidgets('has no note when nothing is open', (tester) async {
      setRequests([
        visit(status: 'declined'),
        visit(id: 2, status: 'cancelled'),
      ]);
      await open(tester);

      expect(find.textContaining('open request'), findsNothing);
      expect(find.text('Request a home check-up'), findsOneWidget);
    });

    testWidgets('stops at three open requests and says how to make room', (
      tester,
    ) async {
      setRequests([
        visit(id: 1, gobikerId: 7),
        visit(id: 2, gobikerId: 8, status: 'accepted'),
        visit(id: 3, gobikerId: 9),
      ]);
      await open(tester);

      expect(find.textContaining('You have 3 open requests'), findsOneWidget);
      expect(find.textContaining('Cancel one in History'), findsOneWidget);
      expect(canPress(tester, 'Request visit'), isFalse);
    });
  });

  group('which answers are new', () {
    test(
      'only an answer from a GoBiker counts, and opening it clears it',
      () async {
        final waiting = visit(id: 1, status: 'pending');
        final cancelled = visit(id: 2, status: 'cancelled');
        final accepted = visit(id: 3, status: 'accepted');
        final declined = visit(id: 4, status: 'declined');
        final store = PatientStore.instance;

        expect(store.isVisitUnseen(waiting), isFalse);
        expect(
          store.isVisitUnseen(cancelled),
          isFalse,
          reason: 'their own doing',
        );
        expect(store.isVisitUnseen(accepted), isTrue);
        expect(store.isVisitUnseen(declined), isTrue);
        expect(
          store.unseenVisitCount([waiting, cancelled, accepted, declined]),
          2,
        );

        await store.markVisitSeen(declined);
        expect(store.isVisitUnseen(declined), isFalse);
        expect(
          store.unseenVisitCount([waiting, cancelled, accepted, declined]),
          1,
        );
      },
    );

    test('an answer that changes is new again', () async {
      final store = PatientStore.instance;
      await store.markVisitSeen(visit(id: 5, status: 'accepted'));

      expect(store.isVisitUnseen(visit(id: 5, status: 'accepted')), isFalse);
      expect(store.isVisitUnseen(visit(id: 5, status: 'completed')), isTrue);
    });

    test(
      'what was already answered before this version is taken as seen, once',
      () async {
        final store = PatientStore.instance;
        final old = [
          visit(id: 1, status: 'declined'),
          visit(id: 2, status: 'completed'),
        ];

        await store.baselineVisits(old);
        expect(store.unseenVisitCount(old), 0);

        // A later answer is new; a second baseline must not swallow it.
        final fresh = visit(id: 3, status: 'declined');
        await store.baselineVisits([...old, fresh]);
        expect(store.isVisitUnseen(fresh), isTrue);
      },
    );

    test('is remembered after the app is closed and opened again', () async {
      final store = PatientStore.instance;
      await store.baselineVisits([visit(id: 1, status: 'accepted')]);
      await store.markVisitSeen(visit(id: 2, status: 'declined'));
      await store.hideDecline(2);

      store.clearSession(); // forgets it in memory, the saved copy stays
      await store.load();

      expect(store.isVisitUnseen(visit(id: 1, status: 'accepted')), isFalse);
      expect(store.isVisitUnseen(visit(id: 2, status: 'declined')), isFalse);
      expect(store.isDeclineHidden(2), isTrue);
    });
  });

  group('History', () {
    Future<void> openHistory(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SafeArea(child: HistoryTab())),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('a visit request opens its details, and that clears the dot', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      setRequests([visit(status: 'declined', note: 'I am away that week.')]);
      await openHistory(tester);

      expect(find.bySemanticsLabel(RegExp('New update')), findsOneWidget);

      await tester.tap(find.text('Home visit request'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Message from Maria Santos'), findsOneWidget);
      expect(find.text('I am away that week.'), findsOneWidget);
      expect(
        PatientStore.instance.isVisitUnseen(visit(status: 'declined')),
        isFalse,
      );

      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.bySemanticsLabel(RegExp('New update')), findsNothing);
      semantics.dispose();
    });

    testWidgets('an accepted request can be cancelled from its details', (
      tester,
    ) async {
      setRequests([visit(status: 'accepted')]);
      await openHistory(tester);

      await tester.tap(find.text('Home visit request'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Cancel request'), findsOneWidget);
      await tester.tap(find.text('Cancel request'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Cancel this request?'), findsOneWidget);
      expect(
        find.text('Maria Santos will be told not to come.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Keep it'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Cancel this request?'), findsNothing);
    });

    testWidgets(
      'a request still waiting is not in History, an answered one is',
      (tester) async {
        setRequests([visit(id: 1, status: 'pending')]);
        await openHistory(tester);
        expect(find.text('Home visit request'), findsNothing);

        for (final status in [
          'accepted',
          'declined',
          'completed',
          'cancelled',
        ]) {
          await tester.pumpWidget(const SizedBox());
          setRequests([visit(id: 1, status: status)]);
          await openHistory(tester);
          expect(
            find.text('Home visit request'),
            findsOneWidget,
            reason: status,
          );
        }
      },
    );

    testWidgets('a request that is over has no cancel button', (tester) async {
      setRequests([visit(status: 'completed')]);
      await openHistory(tester);
      await tester.tap(find.text('Home visit request'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Cancel request'), findsNothing);
      expect(find.text('Visit done'), findsWidgets);
    });

    testWidgets('an SOS request opens its details too', (tester) async {
      ResidentSos.instance
        ..requests = [
          SosEntry.fromJson({
            'id': 9,
            'status': 'sent',
            'status_label': 'Waiting for response',
            'municipality': 'Bugallon',
            'barangay': 'Poblacion',
            'address': '12 Rizal St.',
            'landmark': 'Chapel',
            'created_at': DateTime.now().toIso8601String(),
          }),
        ]
        ..loaded = true;
      await openHistory(tester);

      await tester.tap(find.text('SOS request'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The same card as on Safety, with the way to cancel while it is open.
      expect(find.text('Your SOS request'), findsOneWidget);
      expect(find.text('Cancel SOS'), findsOneWidget);
    });
  });

  group('a declined request', () {
    Future<List<String?>> openDeclined(
      WidgetTester tester, {
      Appointment? request,
      List<Appointment> others = const [],
    }) async {
      final asked = <String?>[];
      final declined =
          request ?? visit(status: 'declined', note: 'I am away that week.');
      setRequests([declined, ...others]);
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: VisitRequestScreen(
            appointmentId: declined.id,
            loader: (barangay) async {
              asked.add(barangay);
              return (
                gobikers: [
                  gobiker(7, 'Maria Santos'), // the one who declined
                  gobiker(8, 'Jose Lim'),
                  gobiker(9, 'Rico Dela'),
                ],
                error: null,
              );
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(
        const Duration(milliseconds: 100),
      ); // the list's answer lands
      return asked;
    }

    testWidgets(
      'shows the message, what was asked, and other GoBikers of its barangay',
      (tester) async {
        final asked = await openDeclined(tester);

        expect(find.text('Message from Maria Santos'), findsOneWidget);
        expect(find.text('I am away that week.'), findsOneWidget);
        expect(
          find.text('Purok 3, near the chapel, Poblacion'),
          findsOneWidget,
        );
        expect(find.text('Blood pressure check for my mother'), findsOneWidget);

        expect(find.text('Ask someone else'), findsOneWidget);
        expect(asked, [
          'Poblacion',
        ], reason: "the request's own barangay first");
        // Not the GoBiker who just said no: the bare name would only be a list tile.
        expect(find.text('Maria Santos'), findsNothing);
        expect(find.text('Jose Lim'), findsOneWidget);
        expect(find.text('Rico Dela'), findsOneWidget);
      },
    );

    testWidgets('does not offer a GoBiker who already has a request open', (
      tester,
    ) async {
      await openDeclined(
        tester,
        others: [visit(id: 2, gobikerId: 8, gobiker: 'Jose Lim')],
      );

      expect(
        find.text('Already asked, waiting for their answer'),
        findsOneWidget,
      );
    });

    testWidgets('sends the same request to the one chosen, after asking', (
      tester,
    ) async {
      await _withServer(server, () async {
        await openDeclined(tester);

        await tester.tap(find.text('Rico Dela'));
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Ask Rico Dela?'), findsOneWidget);
        expect(
          server.posted,
          isEmpty,
          reason: 'nothing is sent before they confirm',
        );

        await tester.tap(find.text('Send request'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(server.posted, hasLength(1));
        final sent = server.posted.single;
        expect(sent['gobiker_id'], 9);
        expect(sent['barangay'], 'Poblacion');
        expect(sent['address'], 'Purok 3, near the chapel');
        expect(sent['reason'], 'Blood pressure check for my mother');
        expect(sent['preferred_window'], 'morning');
        expect(
          PatientStore.instance.isDeclineHidden(1),
          isTrue,
          reason: 'followed up',
        );
      })();
    });

    testWidgets('sends nothing when they change their mind', (tester) async {
      await _withServer(server, () async {
        await openDeclined(tester);
        await tester.tap(find.text('Jose Lim'));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text('Not now'));
        await tester.pump(const Duration(milliseconds: 400));

        expect(server.posted, isEmpty);
        expect(PatientStore.instance.isDeclineHidden(1), isFalse);
      })();
    });

    testWidgets('asks for a new date first when the old one has passed', (
      tester,
    ) async {
      await _withServer(server, () async {
        await openDeclined(
          tester,
          request: visit(
            status: 'declined',
            date: DateTime.now().subtract(const Duration(days: 2)),
          ),
        );

        await tester.tap(find.text('Rico Dela'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('New visit date'), findsOneWidget);

        await tester.tap(find.text('OK'));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text('Send request'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final date = DateTime.parse(
          server.posted.single['preferred_date'] as String,
        );
        expect(date.isBefore(DateUtils.dateOnly(DateTime.now())), isFalse);
      })();
    });

    testWidgets('keeps the declined row and says why when the server refuses', (
      tester,
    ) async {
      server
        ..postStatus = 422
        ..postMessage = 'You can have up to 3 open visit requests. Cancel one first to ask for a new one.';
      await _withServer(server, () async {
        await openDeclined(tester);
        await tester.tap(find.text('Rico Dela'));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text('Send request'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          find.textContaining('up to 3 open visit requests'),
          findsOneWidget,
        );
        expect(PatientStore.instance.isDeclineHidden(1), isFalse);
      })();
    });

    testWidgets('can be hidden from the Home screen', (tester) async {
      await openDeclined(tester);

      await tester.scrollUntilVisible(
        find.text('Hide this from the Home screen'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Hide this from the Home screen'));
      await tester.pump();

      expect(PatientStore.instance.isDeclineHidden(1), isTrue);
    });

    testWidgets('says so when the request is gone', (tester) async {
      setRequests([]);
      await tester.pumpWidget(
        const MaterialApp(home: VisitRequestScreen(appointmentId: 99)),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('This request is no longer here'), findsOneWidget);
    });
  });

  group('the Home screen', () {
    const user = AppUser(
      id: 1,
      name: 'Ana Reyes',
      email: 'ana@example.com',
      role: 'User',
      barangay: 'Poblacion',
    );

    Future<void> openHome(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      // The dashboard asks the server for its lists as it opens: answered by the fake one.
      await http.runWithClient(() async {
        await tester.pumpWidget(
          const MaterialApp(home: ResidentDashboardScreen(currentUser: user)),
        );
        await tester.pump(const Duration(milliseconds: 500));
      }, () => MockClient(server.handle));
    }

    testWidgets(
      'lists a declined visit under Map, and the Home visit row always asks for a new one',
      (tester) async {
        await PatientStore.instance.baselineVisits(
          const [],
        ); // nothing old to swallow
        setRequests([
          visit(status: 'pending', id: 2),
          visit(status: 'declined', note: 'Away.'),
        ]);
        await openHome(tester);

        expect(
          find.text('Ask a GoBiker to check on you at home'),
          findsOneWidget,
        );
        expect(find.text('Visit declined'), findsOneWidget);
        expect(find.textContaining('Tap to ask someone else'), findsOneWidget);
        // The pending request is on Home too, in its own row.
        expect(find.text('Home visit request'), findsOneWidget);
        expect(
          find.textContaining('Waiting for the GoBiker to accept'),
          findsOneWidget,
        );

        // Map comes before it.
        final map = tester.getTopLeft(find.text('Map')).dy;
        final declined = tester.getTopLeft(find.text('Visit declined')).dy;
        expect(declined, greaterThan(map));
      },
    );

    testWidgets(
      'lists open requests under Map: waiting and accepted ones, not finished ones',
      (tester) async {
        setRequests([
          visit(id: 1, status: 'pending', gobikerId: 8),
          visit(id: 2, status: 'accepted', gobikerId: 9),
          visit(id: 3, status: 'completed', gobikerId: 10),
          visit(id: 4, status: 'cancelled', gobikerId: 11),
        ]);
        await openHome(tester);

        expect(find.text('Home visit request'), findsNWidgets(2));
        expect(find.textContaining('Accepted'), findsOneWidget);
        expect(
          find.textContaining('Waiting for the GoBiker to accept'),
          findsOneWidget,
        );
        final map = tester.getTopLeft(find.text('Map')).dy;
        expect(
          tester.getTopLeft(find.text('Home visit request').first).dy,
          greaterThan(map),
        );

        // Tapping one opens its details, where it can be cancelled.
        await tester.tap(find.text('Home visit request').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Cancel request'), findsOneWidget);
      },
    );

    testWidgets('no declined row when nothing was declined, or it was hidden', (
      tester,
    ) async {
      setRequests([visit(status: 'accepted')]);
      await openHome(tester);
      expect(find.text('Visit declined'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      setRequests([visit(id: 5, status: 'declined')]);
      await PatientStore.instance.hideDecline(5);
      await openHome(tester);
      expect(find.text('Visit declined'), findsNothing);
    });

    testWidgets('does not show a decline from long ago', (tester) async {
      setRequests([
        visit(
          status: 'declined',
          changed: DateTime.now().subtract(const Duration(days: 30)),
        ),
      ]);
      await openHome(tester);

      expect(find.text('Visit declined'), findsNothing);
    });

    testWidgets(
      'puts the number of new answers on History, and it goes down as they are opened',
      (tester) async {
        setRequests([
          visit(id: 1, status: 'declined'),
          visit(id: 2, status: 'accepted', gobikerId: 8),
          visit(id: 3, status: 'pending', gobikerId: 9),
        ]);
        await PatientStore.instance.baselineVisits(const []);
        await openHome(tester);

        final bar = find.byType(BottomNavigationBar);
        expect(
          find.descendant(of: bar, matching: find.text('2')),
          findsOneWidget,
        );

        await PatientStore.instance.markVisitSeen(
          visit(id: 1, status: 'declined'),
        );
        await tester.pump();
        expect(
          find.descendant(of: bar, matching: find.text('1')),
          findsOneWidget,
        );

        await PatientStore.instance.markVisitSeen(
          visit(id: 2, status: 'accepted'),
        );
        await tester.pump();
        expect(find.byType(Badge), findsNothing);
      },
    );
  });
}
