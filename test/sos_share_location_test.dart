import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:go_bike_app/core/location_gate.dart';
import 'package:go_bike_app/core/resident_sos.dart';
import 'package:go_bike_app/screens/patient/emergency_request_screen.dart';

/// A phone whose location state the test sets, counting the settings screens it was sent to.
class FakePhone implements LocationPlatform {
  FakePhone({
    this.serviceOn = true,
    this.permission = LocationPermission.whileInUse,
  });

  bool serviceOn;
  LocationPermission permission;
  int locationSettingsOpened = 0;
  int appSettingsOpened = 0;

  @override
  Future<bool> isServiceEnabled() async => serviceOn;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Stream<bool> serviceEnabledChanges() => const Stream.empty();

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsOpened++;
    return true;
  }

  @override
  Future<bool> openAppSettings() async {
    appSettingsOpened++;
    return true;
  }
}

Position pin() => Position(
  latitude: 16.04,
  longitude: 120.33,
  timestamp: DateTime.now(),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

/// Declared with their types: a closure's inferred type would make these `Future<Position>`.
Future<Position?> foundYou() async => pin();
Future<Position?> foundNothing() async => null;

void main() {
  final posted = <Map<String, dynamic>>[];
  var lookups = 0;

  /// What the phone's GPS answers; a test may swap it (a slow GPS never answers).
  late Future<Position?> Function() gps;

  Future<http.Response> handle(http.Request r) async {
    final json = {'content-type': 'application/json'};
    if (r.method == 'POST' && r.url.path.endsWith('/resident/sos')) {
      posted.add(jsonDecode(r.body) as Map<String, dynamic>);
      return http.Response(
        jsonEncode({
          'message': 'Emergency request sent.',
          'sos': {
            'id': 5,
            'status': 'sent',
            'status_label': 'Waiting for response',
            'barangay': 'Poblacion',
            'landmark': 'Chapel',
            'created_at': DateTime.now().toUtc().toIso8601String(),
          },
        }),
        201,
        headers: json,
      );
    }
    return http.Response('{}', 404, headers: json);
  }

  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    ResidentSos.instance.reset();
    posted.clear();
    lookups = 0;
    gps = foundYou;
    ResidentSos.positionSource = () {
      lookups++;
      return gps();
    };
    LocationGate.instance = LocationGate(FakePhone());
  });

  tearDown(() {
    ResidentSos.positionSource = ResidentSos.quickPosition;
    LocationGate.instance = LocationGate();
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EmergencyRequestScreen()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> run(WidgetTester tester, Future<void> Function() body) =>
      http.runWithClient(body, () => MockClient(handle));

  Future<void> fillAndSend(WidgetTester tester) async {
    await tester.enterText(
      find.widgetWithText(TextField, 'House no., street, purok'),
      '12 Rizal St.',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'e.g. Beside the barangay hall'),
      'Beside the chapel',
    );
    await tester.tap(find.text('Send SOS'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 5)); // the snackbar goes away
  }

  bool shareIsOn(WidgetTester tester) => tester
      .widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Share my location'),
      )
      .value;

  Future<void> toggle(WidgetTester tester) async {
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
  }

  testWidgets('offers to share the location, on by default, and looks for it', (
    tester,
  ) async {
    await run(tester, () async {
      await open(tester);

      expect(find.text('Share my location'), findsOneWidget);
      expect(shareIsOn(tester), isTrue);
      expect(
        find.textContaining('Responders see a pin where you are'),
        findsOneWidget,
      );
      expect(lookups, 1);
    });
  });

  testWidgets('sends the position when they share it', (tester) async {
    await run(tester, () async {
      await open(tester);
      await fillAndSend(tester);

      expect(posted.single['latitude'], 16.04);
      expect(posted.single['longitude'], 120.33);
      expect(posted.single['landmark'], 'Beside the chapel');
    });
  });

  testWidgets('sends no position when they turn sharing off, and does not wait '
      'for the GPS', (tester) async {
    // A GPS that never answers: with sharing on this is the 3-second wait.
    gps = () => Completer<Position?>().future;
    await run(tester, () async {
      await open(tester);

      await toggle(tester);
      expect(shareIsOn(tester), isFalse);
      expect(
        find.textContaining('did not share your location'),
        findsOneWidget,
      );
      expect(find.textContaining('Responders see a pin'), findsNothing);

      // Not a single frame is spent waiting: 100 ms is enough for the request to be sent.
      await tester.enterText(
        find.widgetWithText(TextField, 'House no., street, purok'),
        '12 Rizal St.',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'e.g. Beside the barangay hall'),
        'Beside the chapel',
      );
      await tester.tap(find.text('Send SOS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(posted, hasLength(1));
      expect(posted.single.containsKey('latitude'), isFalse);
      expect(posted.single.containsKey('longitude'), isFalse);
      expect(posted.single['address'], '12 Rizal St.');
      await tester.pump(const Duration(seconds: 5));
    });
  });

  testWidgets('looks again, and sends the position, when they turn it back '
      'on', (tester) async {
    await run(tester, () async {
      await open(tester);
      await toggle(tester); // off
      expect(lookups, 1);

      await toggle(tester); // on again
      expect(shareIsOn(tester), isTrue);
      expect(lookups, 2);

      await fillAndSend(tester);
      expect(posted.single['latitude'], 16.04);
    });
  });

  group('when the phone has no location to give', () {
    testWidgets('says location is off, offers settings, and still sends', (
      tester,
    ) async {
      final phone = FakePhone(serviceOn: false);
      LocationGate.instance = LocationGate(phone);
      gps = foundNothing;
      await run(tester, () async {
        await open(tester);

        expect(
          find.text('Location is off on this phone, so no pin will be sent.'),
          findsOneWidget,
        );
        await tester.tap(find.text('Open settings'));
        await tester.pump();
        expect(phone.locationSettingsOpened, 1);

        // Nothing here stops an emergency from being sent.
        await fillAndSend(tester);
        expect(posted, hasLength(1));
        expect(posted.single.containsKey('latitude'), isFalse);
      });
    });

    testWidgets('says the app is not allowed when permission was refused', (
      tester,
    ) async {
      final phone = FakePhone(permission: LocationPermission.deniedForever);
      LocationGate.instance = LocationGate(phone);
      gps = foundNothing;
      await run(tester, () async {
        await open(tester);

        expect(
          find.text(
            'RondaGo is not allowed to use your location, so no pin will be '
            'sent.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Open settings'));
        await tester.pump();
        expect(phone.appSettingsOpened, 1);
      });
    });

    testWidgets('has no warning while it works, or once sharing is off', (
      tester,
    ) async {
      await run(tester, () async {
        await open(tester);
        expect(find.text('Open settings'), findsNothing);
      });

      LocationGate.instance = LocationGate(FakePhone(serviceOn: false));
      gps = foundNothing;
      await run(tester, () async {
        await tester.pumpWidget(const SizedBox());
        await open(tester);
        expect(find.text('Open settings'), findsOneWidget);

        // They chose not to share: the phone's state is no longer their concern.
        await toggle(tester);
        expect(find.text('Open settings'), findsNothing);
      });
    });
  });
}
