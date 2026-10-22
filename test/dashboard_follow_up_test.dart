import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:go_bike_app/core/emergency_watcher.dart';
import 'package:go_bike_app/core/follow_up_alerts.dart';
import 'package:go_bike_app/screens/dashboard_screen.dart';
import 'package:go_bike_app/screens/global_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FollowUpAlerts.instance.reset();
  });

  testWidgets('the dashboard tells the GoBiker about admin updates', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    globalPatients = [
      {
        'name': 'Lola Nena',
        'contact': '0918',
        'follow_up': {
          'decision': 'stop',
          'note': null,
          'decided_at': '2026-10-22T08:00:00+00:00',
        },
      },
      {
        'name': 'Pedro',
        'contact': '0999',
        'follow_up': {
          'decision': 'continue',
          'note': null,
          'decided_at': '2026-10-22T08:00:00+00:00',
        },
      },
    ];

    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('2 updates from the admin'), findsOneWidget);
    expect(find.text('2'), findsWidgets); // the badges on Patients
  });

  testWidgets('no notice when there is nothing new', (tester) async {
    globalPatients = [];
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    await tester.pump(const Duration(seconds: 2));

    expect(find.textContaining('from the admin'), findsNothing);
  });

  testWidgets('the dashboard shows where an emergency stands', (tester) async {
    globalPatients = [];
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await EmergencyWatcher.instance.reset();
    addTearDown(EmergencyWatcher.instance.reset);

    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('The admin saw your alert'), findsNothing);

    EmergencyWatcher.instance.applyServerStatus('responding');
    await tester.pump();

    expect(find.text('The admin saw your alert'), findsOneWidget);
  });
}
