import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_bike_app/core/resident_sos.dart';
import 'package:go_bike_app/core/routing_service.dart';
import 'package:go_bike_app/core/sos_tracking.dart';
import 'package:go_bike_app/screens/patient/resident_dashboard_screen.dart';
import 'package:go_bike_app/screens/patient/safety_tab.dart';
import 'package:go_bike_app/screens/patient/sos_tracking_screen.dart';

Map<String, dynamic> trackingJson({
  String status = 'responding',
  bool tracking = true,
  Map<String, dynamic>? responder,
}) => {
  'sos': {
    'id': 7,
    'status': status,
    'cancelled': false,
    'latitude': 15.9566,
    'longitude': 120.1866,
  },
  'tracking': tracking,
  'responder': tracking
      ? {
          'name': 'Maria Santos',
          'barangay': 'Poblacion',
          'photo_url': null,
          'online': true,
          'latitude': 15.9601,
          'longitude': 120.1902,
          'accuracy': 8,
          'heading': null,
          'position_at': '2026-11-25T10:00:00+00:00',
          ...?responder,
        }
      : null,
};

Future<void> showPanel(
  WidgetTester tester,
  SosTracking? data, {
  RoadRoute? route,
  double? metres,
  DateTime? now,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: SosTrackingPanel(
        data: data,
        route: route,
        straightMetres: metres,
        onShowBoth: () {},
        now: now,
      ),
    ),
  ),
);

void main() {
  group('reading the tracking answer', () {
    test('a GoBiker on the way, with their position', () {
      final t = SosTracking.fromJson(trackingJson());
      expect(t.sosId, 7);
      expect(t.isOpen, isTrue);
      expect(t.sosPoint?.latitude, 15.9566);
      expect(t.responder?.name, 'Maria Santos');
      expect(t.responder?.online, isTrue);
      expect(t.responder?.point?.longitude, 120.1902);
    });

    test('nobody sent yet, or the SOS is over: no GoBiker', () {
      expect(
        SosTracking.fromJson(trackingJson(status: 'sent', tracking: false))
            .responder,
        isNull,
      );
      final over = SosTracking.fromJson(
        trackingJson(status: 'resolved', tracking: false),
      );
      expect(over.isOpen, isFalse);
      expect(over.responder, isNull);
    });

    test('a GoBiker whose phone has not sent a position yet', () {
      final t = SosTracking.fromJson(
        trackingJson(responder: {'latitude': null, 'longitude': null}),
      );
      expect(t.responder?.hasPosition, isFalse);
      expect(t.responder?.point, isNull);
    });

    test('says how long ago simply', () {
      final now = DateTime(2026, 11, 25, 10);
      String ago(Duration d) => sinceLabel(now.subtract(d), now: now);
      expect(ago(const Duration(seconds: 20)), 'just now');
      expect(ago(const Duration(minutes: 3)), '3 min ago');
      expect(ago(const Duration(hours: 2)), '2 h ago');
    });
  });

  group('what the panel under the map says', () {
    testWidgets('waiting for the admin to send a GoBiker', (tester) async {
      await showPanel(
        tester,
        SosTracking.fromJson(trackingJson(status: 'sent', tracking: false)),
      );
      expect(find.text('Waiting for a GoBiker'), findsOneWidget);
      expect(find.text('Show us both'), findsNothing);
    });

    testWidgets('the GoBiker on the way, with the road distance and time', (
      tester,
    ) async {
      await showPanel(
        tester,
        SosTracking.fromJson(trackingJson()),
        route: const RoadRoute(
          points: [],
          distanceMetres: 2400,
          durationSeconds: 700,
        ),
      );
      expect(find.text('Maria Santos'), findsOneWidget);
      expect(find.text('On the way to you'), findsOneWidget);
      expect(find.text('2.4 km by road · ~12 min'), findsOneWidget);
      expect(find.text('Show us both'), findsOneWidget);
    });

    testWidgets('a straight-line distance while there is no road route', (
      tester,
    ) async {
      await showPanel(
        tester,
        SosTracking.fromJson(trackingJson()),
        metres: 640,
      );
      expect(find.text('640 m away (straight line)'), findsOneWidget);
    });

    testWidgets(
      'a GoBiker whose app went quiet shows when they were last seen',
      (tester) async {
        await showPanel(
          tester,
          SosTracking.fromJson(trackingJson(responder: {'online': false})),
          now: DateTime.parse('2026-11-25T10:05:00+00:00').toLocal(),
        );
        expect(
          find.text('Last seen 5 min ago · their app may have lost signal'),
          findsOneWidget,
        );
      },
    );

    testWidgets('once the SOS is resolved, nobody is tracked', (tester) async {
      await showPanel(
        tester,
        SosTracking.fromJson(trackingJson(status: 'resolved', tracking: false)),
      );
      expect(find.text('Your SOS is resolved'), findsOneWidget);
    });
  });

  group('opening the map', () {
    SosEntry sos(int id, String status, {String? responder}) =>
        SosEntry.fromJson({
          'id': id,
          'status': status,
          'created_at': '2026-11-25T10:00:00+00:00',
          if (responder != null) 'responder': {'name': responder},
        });

    test('the Map row goes to the SOS a GoBiker was sent to first', () {
      expect(trackedSos([]), isNull);
      expect(trackedSos([sos(1, 'resolved', responder: 'Maria')]), isNull);
      expect(
        trackedSos([sos(2, 'sent'), sos(1, 'responding', responder: 'Maria')])
            ?.id,
        1,
      );
      expect(trackedSos([sos(2, 'sent')])?.id, 2);
    });

    testWidgets('the SOS card opens the tracking map', (tester) async {
      final original = SosTracking.fetch;
      SosTracking.fetch = (id) async => (
        data: SosTracking.fromJson(
          trackingJson(status: 'sent', tracking: false),
        ),
        error: null,
      );
      addTearDown(() => SosTracking.fetch = original);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SosRequestCard(
                sos: sos(7, 'responding', responder: 'Maria Santos'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('View map · track your GoBiker'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(SosTrackingScreen), findsOneWidget);
      expect(find.text('Waiting for a GoBiker'), findsOneWidget);

      // Leave the screen so its refresh timer stops.
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 400));
    });
  });
}
