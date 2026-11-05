import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_bike_app/core/location_gate.dart';
import 'package:go_bike_app/core/presence_service.dart';
import 'package:go_bike_app/screens/live_map_screen.dart';
import 'package:go_bike_app/widgets/location_help.dart';

/// A phone whose location the test controls, counting what the app asks of it.
class FakePhone implements LocationPlatform {
  FakePhone({
    this.serviceOn = false,
    this.permission = LocationPermission.denied,
  });

  bool serviceOn;
  LocationPermission permission;
  final changes = StreamController<bool>.broadcast();

  int permissionRequests = 0;
  int locationSettingsOpened = 0;
  int appSettingsOpened = 0;

  @override
  Future<bool> isServiceEnabled() async => serviceOn;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Stream<bool> serviceEnabledChanges() => changes.stream;

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

  void turnLocation({required bool on}) {
    serviceOn = on;
    changes.add(on);
  }
}

/// Lets the async work of one step finish.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

/// Frame by frame, because a snackbar only starts sliding in on the frame after the previous
/// one has finished leaving.
Future<void> slideIn(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  late FakePhone phone;
  late LocationGate original;

  setUp(() {
    original = LocationGate.instance;
    phone = FakePhone();
    LocationGate.instance = LocationGate(phone);
  });

  tearDown(() {
    PresenceService.instance.stop();
    LocationGate.instance = original;
  });

  group('LocationGate', () {
    test('reads the phone without ever asking for anything', () async {
      for (final (on, permission, expected) in [
        (false, LocationPermission.always, LocationState.serviceOff),
        (false, LocationPermission.denied, LocationState.serviceOff),
        (true, LocationPermission.denied, LocationState.permissionDenied),
        (
          true,
          LocationPermission.unableToDetermine,
          LocationState.permissionDenied,
        ),
        (
          true,
          LocationPermission.deniedForever,
          LocationState.permissionDeniedForever,
        ),
        (true, LocationPermission.whileInUse, LocationState.ready),
        (true, LocationPermission.always, LocationState.ready),
      ]) {
        phone
          ..serviceOn = on
          ..permission = permission;
        expect(
          await LocationGate.instance.check(),
          expected,
          reason: '$on $permission',
        );
      }
      expect(phone.permissionRequests, 0, reason: 'check() must never prompt');
    });

    test(
      'asks for the permission only when location is on and it can still be asked',
      () async {
        phone.serviceOn = false;
        expect(
          await LocationGate.instance.requestPermission(),
          LocationState.serviceOff,
        );
        expect(
          phone.permissionRequests,
          0,
          reason: 'location off: not ours to ask about',
        );

        phone
          ..serviceOn = true
          ..permission = LocationPermission.deniedForever;
        expect(
          await LocationGate.instance.requestPermission(),
          LocationState.permissionDeniedForever,
        );
        expect(
          phone.permissionRequests,
          0,
          reason: 'blocked for good: nothing to ask',
        );

        phone.permission = LocationPermission.denied;
        await LocationGate.instance.requestPermission();
        expect(phone.permissionRequests, 1);
      },
    );

    test('sends the person to the settings screen that can fix it', () async {
      await LocationGate.instance.openSettingsFor(LocationState.serviceOff);
      await LocationGate.instance.openSettingsFor(
        LocationState.permissionDenied,
      );
      await LocationGate.instance.openSettingsFor(
        LocationState.permissionDeniedForever,
      );
      expect(
        await LocationGate.instance.openSettingsFor(LocationState.ready),
        isFalse,
      );

      expect(phone.locationSettingsOpened, 1);
      expect(phone.appSettingsOpened, 2);
    });

    test('says what is wrong in plain words', () {
      for (final state in LocationState.values.where(
        (s) => s != LocationState.ready,
      )) {
        expect(LocationGate.explain(state), isNotEmpty);
      }
      expect(
        LocationGate.explain(LocationState.serviceOff),
        contains('location is off'),
      );
    });
  });

  group('following the phone for the live map', () {
    late StreamController<Position> positions;
    late int streamsOpened;

    setUp(() {
      streamsOpened = 0;
      positions = StreamController<Position>.broadcast();
      PresenceService.instance.positionStream = () {
        streamsOpened++;
        return positions.stream;
      };
    });

    tearDown(() => positions.close());

    testWidgets(
      'never opens a position stream while location is off, however often the app resumes',
      (tester) async {
        await tester.runAsync(() async {
          final presence = PresenceService.instance;
          presence.watch(); // the live map opens with location off
          await settle();
          expect(streamsOpened, 0);

          // The Google dialog takes the screen and gives it back, over and over:
          // that is what used to open it again every time.
          for (var i = 0; i < 6; i++) {
            presence.didChangeAppLifecycleState(AppLifecycleState.inactive);
            presence.didChangeAppLifecycleState(AppLifecycleState.resumed);
            await settle();
          }

          expect(streamsOpened, 0, reason: 'a refusal must not come back');
          expect(phone.permissionRequests, 0);
        });
      },
    );

    testWidgets(
      'starts by itself when location is switched on, and stops when it goes off again',
      (tester) async {
        await tester.runAsync(() async {
          phone.permission = LocationPermission.whileInUse;
          PresenceService.instance.watch();
          await settle();
          expect(streamsOpened, 0);

          phone.turnLocation(on: true);
          await settle();
          expect(streamsOpened, 1);
          expect(positions.hasListener, isTrue);

          phone.turnLocation(on: false);
          await settle();
          expect(positions.hasListener, isFalse);
          expect(
            streamsOpened,
            1,
            reason: 'off is not a reason to open another',
          );
        });
      },
    );

    testWidgets(
      'pauses in the background and picks up again on return, without asking for anything',
      (tester) async {
        await tester.runAsync(() async {
          phone
            ..serviceOn = true
            ..permission = LocationPermission.whileInUse;
          final presence = PresenceService.instance;
          presence.watch();
          await settle();
          expect(streamsOpened, 1);

          presence.didChangeAppLifecycleState(AppLifecycleState.paused);
          await settle();
          expect(positions.hasListener, isFalse);

          presence.didChangeAppLifecycleState(AppLifecycleState.resumed);
          await settle();
          expect(streamsOpened, 2);
          expect(positions.hasListener, isTrue);
          expect(phone.permissionRequests, 0);
        });
      },
    );

    testWidgets(
      'one stream however many maps are open, and it ends with the last one',
      (tester) async {
        await tester.runAsync(() async {
          phone
            ..serviceOn = true
            ..permission = LocationPermission.always;
          final presence = PresenceService.instance;
          presence
            ..watch()
            ..watch();
          await settle();
          expect(streamsOpened, 1);

          presence.unwatch();
          expect(
            positions.hasListener,
            isTrue,
            reason: 'one map is still open',
          );
          presence.unwatch();
          expect(positions.hasListener, isFalse);
        });
      },
    );

    testWidgets(
      'does not open a stream for a map that was closed while it was being checked',
      (tester) async {
        await tester.runAsync(() async {
          phone
            ..serviceOn = true
            ..permission = LocationPermission.always;
          PresenceService.instance
            ..watch()
            ..unwatch();
          await settle();
          expect(streamsOpened, 0);
        });
      },
    );
  });

  group('the locate button', () {
    Widget host(void Function(BuildContext) onTap) => MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => onTap(context),
            child: const Text('locate'),
          ),
        ),
      ),
    );

    testWidgets(
      'explains once per tap, with a way to the settings, and never stacks messages',
      (tester) async {
        await tester.pumpWidget(
          host(
            (context) => showLocationHelp(context, LocationState.serviceOff),
          ),
        );

        await tester.tap(find.text('locate'));
        await tester.pump();
        await tester.tap(find.text('locate'));
        // The first message slides out, then the second slides in.
        await slideIn(tester);

        expect(find.textContaining('location is off'), findsOneWidget);

        await tester.tap(find.text('Open settings'));
        await tester.pump();
        expect(phone.locationSettingsOpened, 1);
        expect(phone.appSettingsOpened, 0);
      },
    );

    testWidgets('a blocked permission opens the app settings instead', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          (context) =>
              showLocationHelp(context, LocationState.permissionDeniedForever),
        ),
      );
      await tester.tap(find.text('locate'));
      await slideIn(tester);
      await tester.tap(find.text('Open settings'));
      await tester.pump();

      expect(phone.appSettingsOpened, 1);
    });

    testWidgets('says nothing when location is fine', (tester) async {
      await tester.pumpWidget(
        host((context) => showLocationHelp(context, LocationState.ready)),
      );
      await tester.tap(find.text('locate'));
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets(
      'on the live map, tapping Center on me with location off explains and asks nothing',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: LiveMapScreen()));
        await tester.pump(const Duration(milliseconds: 300));

        // Opening the map was quiet: nothing was said, nothing was asked of the phone.
        expect(find.byType(SnackBar), findsNothing);
        expect(phone.permissionRequests, 0);

        await tester.tap(find.byTooltip('Center on me'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.textContaining('location is off'), findsOneWidget);
        expect(find.text('Open settings'), findsOneWidget);
        expect(phone.permissionRequests, 0);

        await tester.pumpWidget(const SizedBox());
      },
    );
  });
}
