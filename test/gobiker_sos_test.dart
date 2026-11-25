import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_bike_app/core/live_map.dart';
import 'package:go_bike_app/core/resident_sos.dart';
import 'package:go_bike_app/core/sos_tracking.dart';
import 'package:go_bike_app/core/theme.dart';
import 'package:go_bike_app/screens/patient/safety_tab.dart';
import 'package:go_bike_app/widgets/assigned_sos_card.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A GoBiker's own emergency is shown with the resident's SOS card, the
/// tracking map and, for the GoBiker sent to help, the assigned SOS card.
void main() {
  testWidgets(
    'the card says emergency and cancels through the given callback',
    (tester) async {
      var cancels = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SosRequestCard(
                sos: SosEntry.fromJson({
                  'id': 5,
                  'status': 'responding',
                  'created_at': '2026-11-25T10:00:00+00:00',
                  'responder': {'name': 'Jose Lim'},
                }),
                title: 'Your emergency',
                noun: 'emergency',
                onCancel: () async {
                  cancels++;
                  return null;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Your emergency'), findsOneWidget);
      expect(find.text('Jose Lim is on the way to help you.'), findsOneWidget);
      expect(find.text('Cancel emergency'), findsOneWidget);

      await tester.ensureVisible(find.text('Cancel emergency'));
      await tester.tap(find.text('Cancel emergency'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel your emergency?'), findsOneWidget);
      expect(
        find.text('Jose Lim is on the way. They will be told not to come.'),
        findsOneWidget,
      );
      expect(find.text('Keep it'), findsOneWidget);

      // The dialog's confirm button, not the card's button behind it.
      await tester.tap(find.text('Cancel emergency').last);
      await tester.pumpAndSettle();

      expect(cancels, 1);
      expect(find.text('Emergency cancelled.'), findsOneWidget);
    },
  );

  test('tracking uses the path it is given', () async {
    final asked = <String>[];
    Future<http.Response> handle(http.Request req) async {
      asked.add(req.url.path);
      return http.Response(
        '{"sos":{"id":7,"status":"sent"},"tracking":false}',
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    await http.runWithClient(() async {
      final gobiker = await SosTracking.load(
        7,
        path: '/gobiker/emergency/7/tracking',
      );
      expect(gobiker.data?.sosId, 7);
      await SosTracking.load(7);
    }, () => MockClient(handle));

    expect(asked, hasLength(2));
    expect(asked.first, endsWith('/gobiker/emergency/7/tracking'));
    expect(asked.last, endsWith('/resident/sos/7/tracking'));
  });

  test('an SOS from a GoBiker is marked', () {
    expect(
      AssignedSos.fromJson({'id': 1, 'from_gobiker': true}).fromGobiker,
      isTrue,
    );
    expect(AssignedSos.fromJson({'id': 1}).fromGobiker, isFalse);
  });

  testWidgets('the helper sees it is a GoBiker in trouble', (tester) async {
    Future<void> pump(bool fromGobiker) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: AssignedSosCard(
              sos: AssignedSos(
                id: 3,
                status: 'responding',
                residentName: 'Ana Cruz',
                address: '',
                landmark: '',
                fromGobiker: fromGobiker,
              ),
              onDirections: () {},
              onResolve: () {},
              onDecline: () {},
            ),
          ),
        ),
      ),
    );

    await pump(true);
    expect(find.text('GoBiker emergency · Responding'), findsOneWidget);
    expect(find.text('SOS · Responding'), findsNothing);

    await pump(false);
    expect(find.text('SOS · Responding'), findsOneWidget);
  });
}
