import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_bike_app/core/app_navigator.dart';
import 'package:go_bike_app/core/live_map.dart';
import 'package:go_bike_app/core/push_service.dart';
import 'package:go_bike_app/core/theme.dart';
import 'package:go_bike_app/widgets/assigned_sos_card.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The "Emergency assigned to you" alert: it can be declined, it comes back
/// when the admin sends the same GoBiker again, and the card names the other
/// GoBikers on the way.
void main() {
  setUp(() {
    vibrateUrgently = () async {};
    PushService.instance.reset();
  });

  testWidgets('the alert offers Accept and Decline', (tester) async {
    await tester.pumpWidget(
      MaterialApp(navigatorKey: appNavigatorKey, home: const Scaffold()),
    );

    final choice = showSosAssignedAlert(residentName: 'Ana Reyes', place: '');
    await tester.pumpAndSettle();

    expect(find.text('Accept'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Decline'), findsOneWidget);

    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();

    expect(await choice, SosAlertChoice.decline);
    expect(find.text('Emergency assigned to you'), findsNothing);
  });

  test('the same SOS sent again alerts again; the same push does not', () {
    final push = PushService.instance;
    const first = '2026-11-26T10:00:00+00:00';

    expect(push.alertOnce(7, first), isTrue);
    expect(push.alertOnce(7, first), isFalse); // a repeated push
    // The same moment written another way is still the same assignment.
    expect(push.alertOnce(7, '2026-11-26T18:00:00+08:00'), isFalse);
    // Declined, then sent again: a new assignment.
    expect(push.alertOnce(7, '2026-11-26T10:05:00+00:00'), isTrue);
    expect(push.alertOnce(8, first), isTrue);

    push.reset();
    expect(push.alertOnce(7, first), isTrue);
  });

  test('two loads at once share one request', () async {
    var requests = 0;
    final reply = Completer<void>();
    Future<http.Response> handle(http.Request req) async {
      requests++;
      await reply.future;
      return http.Response(
        '{"sos":[{"id":3,"status":"responding","resident_name":"Ana Reyes",'
        '"assigned_at":"2026-11-26T10:00:00+00:00"}]}',
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    await http.runWithClient(() async {
      final a = GobikerSos.instance.load();
      final b = GobikerSos.instance.load();
      reply.complete();
      await Future.wait([a, b]);
    }, () => MockClient(handle));

    expect(requests, 1);
    // The second caller waited for the list, not an empty one.
    expect(GobikerSos.instance.open.single.id, 3);
    GobikerSos.instance.reset();
  });

  test('an SOS reads when it was assigned and who else responds', () {
    final sos = AssignedSos.fromJson({
      'id': 4,
      'assigned_at': '2026-11-26T10:00:00+00:00',
      'other_responders': ['Maria Cruz', '', 7],
    });
    expect(sos.assignedAt, DateTime.utc(2026, 11, 26, 10));
    expect(sos.otherResponders, ['Maria Cruz', '7']);

    // An older server sends neither.
    final old = AssignedSos.fromJson({'id': 4});
    expect(old.assignedAt, isNull);
    expect(old.otherResponders, isEmpty);
  });

  testWidgets('the card names the other GoBikers responding', (tester) async {
    Future<void> pump(AssignedSos sos) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: AssignedSosCard(
              sos: sos,
              onDirections: () {},
              onResolve: () {},
              onDecline: () {},
            ),
          ),
        ),
      ),
    );

    await pump(
      AssignedSos.fromJson({
        'id': 4,
        'resident_name': 'Ana Reyes',
        'other_responders': ['Maria Cruz'],
      }),
    );
    expect(find.text('Also responding: Maria Cruz'), findsOneWidget);

    await pump(AssignedSos.fromJson({'id': 4, 'resident_name': 'Ana Reyes'}));
    expect(find.textContaining('Also responding'), findsNothing);
  });
}
