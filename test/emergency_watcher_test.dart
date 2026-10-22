import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:go_bike_app/core/app_navigator.dart';
import 'package:go_bike_app/core/emergency_watcher.dart';
import 'package:go_bike_app/widgets/emergency_status_card.dart';

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
    expect(find.text('The admin is responding'), findsOneWidget);

    watcher.applyServerStatus(null);
    await tester.pump();
    expect(find.text('Emergency resolved'), findsOneWidget);

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pump();
    expect(find.text('Emergency resolved'), findsNothing);
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
    expect(find.text('The admin is responding'), findsOneWidget);
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
