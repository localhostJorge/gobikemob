import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:go_bike_app/core/app_navigator.dart';
import 'package:go_bike_app/core/emergency_watcher.dart';
import 'package:go_bike_app/core/theme.dart';
import 'package:go_bike_app/widgets/emergency_status_card.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late EmergencyWatcher watcher;
  late List<EmergencyPhase> announced;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    watcher = EmergencyWatcher.instance;
    await watcher.reset();
    announced = [];
    watcher.onAnnounce = announced.add;
  });

  tearDown(() async => watcher.reset());

  test('nothing is shown until an emergency is sent', () {
    expect(watcher.phase, EmergencyPhase.none);
    expect(watcher.isOpen, isFalse);

    watcher.applyServerStatus(null);

    expect(watcher.phase, EmergencyPhase.none);
    expect(announced, isEmpty);
  });

  test('follows an emergency from sent to responding to resolved', () async {
    await watcher.markSent();
    expect(watcher.phase, EmergencyPhase.waiting);
    expect(watcher.isOpen, isTrue);

    watcher.applyServerStatus('emergency'); // admin has not answered yet
    expect(watcher.phase, EmergencyPhase.waiting);
    expect(announced, isEmpty);

    watcher.applyServerStatus('responding');
    expect(watcher.phase, EmergencyPhase.responding);
    expect(announced, [EmergencyPhase.responding]);

    watcher.applyServerStatus(
      'responding',
    ); // still responding: no second alert
    expect(announced, [EmergencyPhase.responding]);

    watcher.applyServerStatus(null); // the admin pressed Resolve
    expect(watcher.phase, EmergencyPhase.resolved);
    expect(watcher.isOpen, isFalse);
    expect(announced, [EmergencyPhase.responding, EmergencyPhase.resolved]);
  });

  test('resolved without a response in between is still announced', () async {
    await watcher.markSent();

    watcher.applyServerStatus(null);

    expect(watcher.phase, EmergencyPhase.resolved);
    expect(announced, [EmergencyPhase.resolved]);
  });

  test('the resolved notice stays until it is dismissed', () async {
    await watcher.markSent();
    watcher.applyServerStatus(null);

    watcher.applyServerStatus(null); // asking again changes nothing
    expect(watcher.phase, EmergencyPhase.resolved);
    expect(announced.length, 1);

    await watcher.dismissResolved();
    expect(watcher.phase, EmergencyPhase.none);
  });

  test('an emergency open on the server is picked up quietly', () {
    watcher.applyServerStatus('emergency');

    expect(watcher.phase, EmergencyPhase.waiting);
    expect(announced, isEmpty);
  });

  test(
    'an emergency left open is remembered when the app starts again',
    () async {
      // The phone remembers it was waiting; the app starts fresh.
      SharedPreferences.setMockInitialValues({'emergency_phase': 'responding'});

      await watcher.load();

      expect(watcher.phase, EmergencyPhase.responding);
      expect(watcher.isOpen, isTrue);

      // The admin resolved it while the app was closed: the next check says so.
      watcher.applyServerStatus(null);
      expect(watcher.phase, EmergencyPhase.resolved);
      expect(announced, [EmergencyPhase.resolved]);
    },
  );

  test('signing out forgets the emergency', () async {
    await watcher.markSent();

    await watcher.reset();

    expect(watcher.phase, EmergencyPhase.none);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('emergency_phase'), isNull);
  });

  const responding = {
    'status': 'responding',
    'sos': {
      'id': 5,
      'status': 'responding',
      'status_label': 'Responding',
      'barangay': 'Poblacion',
      'created_at': '2026-11-25T10:00:00+00:00',
      'responder': {'name': 'Jose Lim'},
    },
  };

  test('keeps the SOS the server sends with the status', () async {
    await watcher.markSent();

    watcher.applyServer(responding);

    expect(watcher.phase, EmergencyPhase.responding);
    expect(watcher.current?.id, 5);
    expect(watcher.current?.responderName, 'Jose Lim');
  });

  test('an old server without an SOS leaves it empty', () {
    watcher.applyServer({'status': 'emergency'});

    expect(watcher.phase, EmergencyPhase.waiting);
    expect(watcher.current, isNull);
  });

  test('cancelling does not announce resolved', () async {
    await watcher.markSent();
    watcher.applyServer(responding);
    announced.clear();

    final asked = <String>[];
    final error = await http.runWithClient(
      () => watcher.cancel(),
      () => MockClient((req) async {
        asked.add('${req.method} ${req.url.path}');
        return http.Response(
          '{"message":"Emergency cancelled.","sos":null}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    expect(error, isNull);
    expect(asked.single, endsWith('/gobiker/emergency/cancel'));
    expect(asked.single, startsWith('POST'));
    expect(watcher.phase, EmergencyPhase.none);
    expect(watcher.current, isNull);
    expect(announced, isEmpty);
  });

  test('a refused cancel keeps the emergency and says why', () async {
    await watcher.markSent();
    watcher.applyServer(responding);

    final error = await http.runWithClient(
      () => watcher.cancel(),
      () => MockClient(
        (req) async => http.Response(
          '{"message":"This emergency is already closed."}',
          422,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    expect(error, 'This emergency is already closed.');
    expect(watcher.phase, EmergencyPhase.responding);
    expect(watcher.current?.id, 5);
  });

  testWidgets('the GoBiker sees who is coming and can cancel the emergency', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: SingleChildScrollView(child: EmergencyStatusCard()),
        ),
      ),
    );

    await watcher.markSent();
    watcher.applyServer(responding);
    await tester.pump();

    expect(find.text('Your emergency'), findsOneWidget);
    expect(find.text('Jose Lim is on the way to help you.'), findsOneWidget);
    expect(find.text('Cancel emergency'), findsOneWidget);
    expect(find.text('The admin saw your alert'), findsNothing);
    // Stops the watcher's polling timer before the test ends.
    await watcher.reset();
    await tester.pump();
  });

  testWidgets('an old server without an SOS still shows the plain card', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: EmergencyStatusCard())),
    );

    await watcher.markSent();
    watcher.applyServer({'status': 'emergency'});
    await tester.pump();

    expect(find.text('Emergency alert sent'), findsOneWidget);
    expect(find.text('Cancel emergency'), findsNothing);
    // Stops the watcher's polling timer before the test ends.
    await watcher.reset();
    await tester.pump();
  });

  testWidgets('the status card follows the emergency', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: EmergencyStatusCard())),
    );
    expect(find.text('Emergency alert sent'), findsNothing);

    await watcher.markSent();
    await tester.pump();
    expect(find.text('Emergency alert sent'), findsOneWidget);

    watcher.applyServerStatus('responding');
    await tester.pump();
    expect(find.text('The admin saw your alert'), findsOneWidget);

    watcher.applyServerStatus(null);
    await tester.pump();
    expect(find.text('Emergency resolved'), findsOneWidget);

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pump();
    expect(find.text('Emergency resolved'), findsNothing);
  });

  testWidgets('the phone vibrates for one second with every pop-up', (
    tester,
  ) async {
    final original = vibratePhone;
    var buzzes = 0;
    vibratePhone = () async => buzzes++;
    addTearDown(() => vibratePhone = original);

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: appNavigatorKey,
        home: const Scaffold(body: Text('Home')),
      ),
    );

    showEmergencyAlert(EmergencyPhase.responding);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    showEmergencyAlert(EmergencyPhase.resolved);
    await tester.pumpAndSettle();

    expect(buzzes, 2); // once for Responding, once for Resolve
    expect(emergencyVibration, const Duration(seconds: 1));

    // Nothing to tell the GoBiker about: no pop-up, no vibration.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    showEmergencyAlert(EmergencyPhase.waiting);
    await tester.pumpAndSettle();
    expect(buzzes, 2);
  });

  testWidgets('the pop-up says what the admin did', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: appNavigatorKey,
        home: const Scaffold(body: Text('Patient form')),
      ),
    );

    showEmergencyAlert(EmergencyPhase.responding);
    await tester.pumpAndSettle();
    expect(find.text('The admin saw your alert'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    showEmergencyAlert(EmergencyPhase.resolved);
    await tester.pumpAndSettle();
    expect(find.text('Emergency resolved'), findsOneWidget);
    expect(
      find.textContaining('marked your emergency as resolved'),
      findsOneWidget,
    );
  });
}
