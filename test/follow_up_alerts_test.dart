import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:go_bike_app/core/follow_up.dart';
import 'package:go_bike_app/core/follow_up_alerts.dart';
import 'package:go_bike_app/widgets/follow_up_banner.dart';

Map<String, dynamic> _patient(
  String name,
  String contact, {
  String? decision,
  String decidedAt = '2026-10-22T08:00:00+00:00',
}) => {
  'id': '$name$contact',
  'name': name,
  'contact': contact,
  'follow_up': decision == null
      ? null
      : {'decision': decision, 'note': null, 'decided_at': decidedAt},
};

void main() {
  late FollowUpAlerts alerts;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    alerts = FollowUpAlerts.instance..reset();
  });

  test('counts each person with an unseen decision once', () {
    alerts.sync([
      _patient('Lola Nena', '0918', decision: 'stop'),
      _patient(
        'lola nena ',
        '0918',
        decision: 'stop',
      ), // another check-up, same person
      _patient('Pedro', '0999', decision: 'continue'),
      _patient('Ana', '0111'), // no decision
    ]);

    expect(alerts.count, 2);
  });

  test('opening a record marks that person as seen', () async {
    final lola = _patient('Lola Nena', '0918', decision: 'stop');
    final pedro = _patient('Pedro', '0999', decision: 'continue');
    alerts.sync([lola, pedro]);
    expect(alerts.isNew(lola), isTrue);

    await alerts.markSeen(lola);

    expect(alerts.isNew(lola), isFalse);
    expect(alerts.isNew(pedro), isTrue);
    expect(alerts.count, 1);
  });

  test('a changed decision is new again', () async {
    final first = _patient('Lola Nena', '0918', decision: 'continue');
    alerts.sync([first]);
    await alerts.markSeen(first);
    expect(alerts.count, 0);

    final changed = _patient(
      'Lola Nena',
      '0918',
      decision: 'stop',
      decidedAt: '2026-10-25T08:00:00+00:00',
    );
    alerts.sync([changed]);

    expect(alerts.count, 1);
    expect(alerts.isNew(changed), isTrue);
  });

  test('what was seen is remembered after the app restarts', () async {
    final lola = _patient('Lola Nena', '0918', decision: 'stop');
    alerts.sync([lola]);
    await alerts.markSeen(lola);

    // A new app start: the in-memory state is gone, the phone's storage is not.
    final saved = await SharedPreferences.getInstance();
    final stored = saved.getString('follow_up_seen');
    alerts.reset();
    SharedPreferences.setMockInitialValues({'follow_up_seen': stored!});

    await alerts.load();
    alerts.sync([lola]);

    expect(alerts.count, 0);
    expect(alerts.isNew(lola), isFalse);
  });

  test('tells listeners when the count changes', () {
    var calls = 0;
    alerts.addListener(() => calls++);

    alerts.sync([_patient('Lola Nena', '0918', decision: 'stop')]);
    alerts.sync([_patient('Lola Nena', '0918', decision: 'stop')]); // no change

    expect(calls, 1);
  });

  testWidgets('the tag shows a red dot and New for an unseen decision', (
    tester,
  ) async {
    final followUp = FollowUp.from({'decision': 'stop'})!;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              FollowUpChip(followUp: followUp, isNew: true),
              FollowUpChip(followUp: followUp),
            ],
          ),
        ),
      ),
    );

    expect(find.text('New · Stop checking'), findsOneWidget);
    expect(find.text('Stop checking'), findsOneWidget);
  });
}
