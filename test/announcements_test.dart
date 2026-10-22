import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:go_bike_app/core/announcements.dart';
import 'package:go_bike_app/screens/announcements_screen.dart';
import 'package:go_bike_app/screens/dashboard_screen.dart';
import 'package:go_bike_app/screens/global_state.dart';

Announcement _a(
  int id,
  String title, {
  String body = 'Details.',
  DateTime? expires,
}) => Announcement(
  id: id,
  title: title,
  body: body,
  postedAt: DateTime(2026, 10, 22, 8),
  expiresAt: expires,
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Announcements.instance.reset();
  });

  test('reads what the server sends and skips broken entries', () {
    final ok = Announcement.from({
      'id': 7,
      'title': ' Schedule update ',
      'body': 'Starts at 7:30 AM.',
      'posted_at': '2026-10-22T08:00:00+00:00',
      'expires_at': null,
    })!;

    expect(ok.id, 7);
    expect(ok.title, 'Schedule update');
    expect(ok.expiresAt, isNull);
    expect(Announcement.from({'id': 1, 'title': ''}), isNull);
    expect(Announcement.from('nope'), isNull);
  });

  test('an announcement past its end date is not shown', () {
    Announcements.instance.setItems([
      _a(1, 'Live'),
      _a(
        2,
        'Ended',
        expires: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      _a(3, 'Ends later', expires: DateTime.now().add(const Duration(days: 2))),
    ]);

    expect(Announcements.instance.items.map((a) => a.title), [
      'Live',
      'Ends later',
    ]);
    expect(Announcements.instance.latest!.title, 'Live');
  });

  test('new until the GoBiker opens them, and remembered after that', () async {
    final list = Announcements.instance;
    list.setItems([_a(1, 'One'), _a(2, 'Two')]);
    expect(list.unseenCount, 2);
    expect(list.isNew(list.items.first), isTrue);

    await list.markAllSeen();

    expect(list.unseenCount, 0);
    // What was seen is on the phone: a fresh start still knows it.
    final saved = (await SharedPreferences.getInstance()).getStringList(
      'announcements_seen',
    );
    expect(saved, containsAll(['1', '2']));
  });

  test('an announcement that arrives later is new again', () async {
    final list = Announcements.instance;
    list.setItems([_a(1, 'One')]);
    await list.markAllSeen();

    list.setItems([_a(2, 'Two'), _a(1, 'One')]);

    expect(list.unseenCount, 1);
    expect(list.isNew(list.items.first), isTrue); // Two
  });

  test('signing out forgets the announcements', () async {
    Announcements.instance.setItems([_a(1, 'One')]);
    await Announcements.instance.markAllSeen();

    await Announcements.instance.reset();

    expect(Announcements.instance.items, isEmpty);
    expect(
      (await SharedPreferences.getInstance()).getString('announcements_cache'),
      isNull,
    );
  });

  testWidgets('the list screen shows every announcement and the New tags', (
    tester,
  ) async {
    Announcements.instance.setItems([
      _a(2, 'Newest news'),
      _a(1, 'Older news'),
    ]);

    await tester.pumpWidget(const MaterialApp(home: AnnouncementsScreen()));
    await tester.pump();

    expect(find.text('Newest news'), findsOneWidget);
    expect(find.text('Older news'), findsOneWidget);
    expect(find.text('New'), findsNWidgets(2));
    expect(Announcements.instance.unseenCount, 0); // opening marks them seen
  });

  testWidgets('the list screen says when there is nothing', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AnnouncementsScreen()));
    await tester.pump();

    expect(find.text('No announcements'), findsOneWidget);
  });

  testWidgets(
    'the dashboard shows the admin announcement, not the sample one',
    (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      globalPatients = [];
      Announcements.instance.setItems([
        _a(2, 'Bring your ID', body: 'The RHU checks IDs on Friday.'),
        _a(1, 'Older'),
      ]);

      await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Bring your ID'), findsOneWidget);
      expect(find.text('Ronda Schedule Update'), findsNothing);
      expect(find.textContaining('1 more'), findsOneWidget);
    },
  );

  testWidgets('the dashboard says so when there are no announcements', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    globalPatients = [];

    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    await tester.pump(const Duration(seconds: 2));

    expect(find.textContaining('No announcements right now'), findsOneWidget);
  });
}
