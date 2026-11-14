import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:go_bike_app/core/live_map.dart';
import 'package:go_bike_app/core/location_gate.dart';
import 'package:go_bike_app/core/presence_service.dart';
import 'package:go_bike_app/screens/live_map_screen.dart';

/// About one metre north per 0.000009 degrees of latitude.
const double _metre = 0.000009;

MapPerson biker(int id, double metresNorth, {double? accuracy}) => MapPerson(
  id: id,
  name: 'GoBiker $id',
  latitude: 15.9566 + metresNorth * _metre,
  longitude: 120.1866,
  accuracy: accuracy,
);

double metresBetween(LatLng a, LatLng b) =>
    const Distance().as(LengthUnit.Meter, a, b);

/// A phone with location switched off: the map draws nobody as "you".
class NoLocation implements LocationPlatform {
  @override
  Future<bool> isServiceEnabled() async => false;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.denied;
  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.denied;
  @override
  Stream<bool> serviceEnabledChanges() => const Stream.empty();
  @override
  Future<bool> openLocationSettings() async => true;
  @override
  Future<bool> openAppSettings() async => true;
}

void main() {
  group('what the server says about a position', () {
    test(
      'a GoBiker\'s accuracy is read, and a rough one is known as rough',
      () {
        final sharp = MapPerson.fromJson({
          'id': 1,
          'name': 'Maria',
          'latitude': 15.9566,
          'longitude': 120.1866,
          'accuracy': 8.5,
        })!;
        final rough = MapPerson.fromJson({
          'id': 2,
          'name': 'Jose',
          'latitude': 15.9566,
          'longitude': 120.1866,
          'accuracy': 85,
        })!;

        expect(sharp.accuracy, 8.5);
        expect(sharp.isRough, isFalse);
        expect(rough.isRough, isTrue);
      },
    );

    test('a server that sends no accuracy is still read', () {
      final p = MapPerson.fromJson({
        'id': 1,
        'name': 'Maria',
        'latitude': 15.9566,
        'longitude': 120.1866,
      })!;

      expect(p.accuracy, isNull);
      expect(p.isRough, isFalse);
    });

    test(
      'an SOS pin within 50 m is exact enough; beyond that, approximate',
      () {
        AssignedSos sos(Object? accuracy) => AssignedSos.fromJson({
          'id': 1,
          'status': 'responding',
          'latitude': 15.95,
          'longitude': 120.18,
          'accuracy': accuracy,
        });

        expect(sos(8).isApproximate, isFalse);
        expect(sos(40).isRough, isTrue); // a circle, but not yet a warning
        expect(sos(40).isApproximate, isFalse);
        expect(sos(140).isApproximate, isTrue);
        expect(sos(null).isApproximate, isFalse);
        expect(sos(-1).accuracy, isNull);
      },
    );

    test('an SOS with no pin is never called approximate', () {
      final sos = AssignedSos.fromJson({
        'id': 1,
        'status': 'responding',
        'accuracy': 500,
      });

      expect(sos.isApproximate, isFalse);
      expect(sos.isRough, isFalse);
    });
  });

  group('a marker on the move', () {
    test('appears where the GoBiker is, without sliding in from anywhere', () {
      final glide = MarkerGlide()..retarget([biker(1, 0)], progress: 0);

      expect(glide.at(1, 0), biker(1, 0).point);
      expect(glide.at(1, 1), biker(1, 0).point);
    });

    test('glides from where it was to where the GoBiker now is', () {
      final glide = MarkerGlide()
        ..retarget([biker(1, 0)], progress: 0)
        ..retarget([biker(1, 20)], progress: 1);

      expect(metresBetween(glide.at(1, 0)!, biker(1, 0).point), lessThan(1));
      expect(metresBetween(glide.at(1, 0.5)!, biker(1, 10).point), lessThan(1));
      expect(metresBetween(glide.at(1, 1)!, biker(1, 20).point), lessThan(1));
    });

    test('a new position mid-move starts from where the marker is drawn', () {
      final glide = MarkerGlide()
        ..retarget([biker(1, 0)], progress: 0)
        ..retarget([biker(1, 20)], progress: 1)
        // Halfway there (drawn at 10 m) when the next position arrives.
        ..retarget([biker(1, 40)], progress: 0.5);

      expect(metresBetween(glide.at(1, 0)!, biker(1, 10).point), lessThan(1));
      expect(metresBetween(glide.at(1, 1)!, biker(1, 40).point), lessThan(1));
    });

    test('a jump too big to be a ride is shown at once', () {
      final glide = MarkerGlide()
        ..retarget([biker(1, 0)], progress: 0)
        ..retarget([biker(1, 900)], progress: 1);

      expect(glide.at(1, 0), biker(1, 900).point);
    });

    test('nothing glides for someone who turned animations off', () {
      final glide = MarkerGlide()
        ..retarget([biker(1, 0)], progress: 0)
        ..retarget([biker(1, 20)], progress: 1, animate: false);

      expect(glide.at(1, 0), biker(1, 20).point);
    });

    test('a GoBiker who went offline is forgotten; one never seen is null', () {
      final glide = MarkerGlide()
        ..retarget([biker(1, 0), biker(2, 5)], progress: 0)
        ..retarget([biker(2, 5)], progress: 1);

      expect(glide.at(1, 1), isNull);
      expect(glide.at(2, 1), biker(2, 5).point);
      expect(glide.at(99, 0), isNull);
    });
  });

  group('the live map screen', () {
    setUp(() {
      SharedPreferences.resetStatic();
      SharedPreferences.setMockInitialValues({});
      LocationGate.instance = LocationGate(NoLocation());
    });

    tearDown(() {
      PresenceService.instance.stop();
      LocationGate.instance = LocationGate();
    });

    Future<http.Response> server(http.Request r) async => http.Response(
      jsonEncode({
        'barangay': 'Poblacion',
        'gobikers': [
          {
            'id': 1,
            'name': 'Maria Santos',
            'latitude': 15.9566,
            'longitude': 120.1866,
            'accuracy': 6,
            'status': 'active',
          },
          {
            'id': 2,
            'name': 'Jose Lim',
            'latitude': 15.9590,
            'longitude': 120.1900,
            'accuracy': 85,
            'status': 'active',
          },
        ],
      }),
      200,
      headers: {'content-type': 'application/json'},
    );

    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LiveMapScreen()));
      await tester.pump(const Duration(milliseconds: 300));
    }

    List<CircleMarker> circles(WidgetTester tester) => tester
        .widget<CircleLayer<Object>>(find.byType(CircleLayer<Object>))
        .circles;

    testWidgets('draws a circle only around the GoBiker whose position is '
        'rough', (tester) async {
      await http.runWithClient(() async {
        await open(tester);

        expect(
          tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
          hasLength(2),
        );
        final rings = circles(tester);
        expect(rings, hasLength(1));
        expect(rings.single.radius, 85);
        expect(rings.single.useRadiusInMeter, isTrue);
        expect(rings.single.point, const LatLng(15.9590, 120.1900));

        await tester.pumpWidget(const SizedBox());
      }, () => MockClient(server));
    });

    testWidgets('never asks the satellite server for a zoom it does not '
        'have', (tester) async {
      await http.runWithClient(() async {
        await open(tester);

        final layers = tester.widgetList<TileLayer>(find.byType(TileLayer));
        expect(layers, hasLength(3)); // pictures, roads, place names
        for (final layer in layers) {
          expect(layer.urlTemplate, contains('server.arcgisonline.com'));
          expect(layer.maxNativeZoom, 18);
        }

        await tester.pumpWidget(const SizedBox());
      }, () => MockClient(server));
    });

    testWidgets('switches to the street map and back, and remembers it', (
      tester,
    ) async {
      await http.runWithClient(() async {
        await open(tester);
        expect(find.text('Esri, Maxar, Earthstar Geographics'), findsOneWidget);

        await tester.tap(find.byTooltip('Show the street map'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final layer = tester.widget<TileLayer>(find.byType(TileLayer));
        expect(layer.urlTemplate, contains('tile.openstreetmap.org'));
        expect(find.text('OpenStreetMap contributors'), findsOneWidget);
        expect(find.byTooltip('Show satellite'), findsOneWidget);
        expect(
          (await SharedPreferences.getInstance()).getBool('live_map_satellite'),
          isFalse,
        );

        // Closed and opened again: it comes back as they left it.
        await tester.pumpWidget(const SizedBox());
        await open(tester);
        expect(find.byTooltip('Show satellite'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
      }, () => MockClient(server));
    });

    testWidgets('fetches every 3 seconds, and not at all while the app is in '
        'the background', (tester) async {
      var requests = 0;
      await http.runWithClient(
        () async {
          await open(tester);
          expect(requests, 1);

          await tester.pump(const Duration(seconds: 3));
          await tester.pump(const Duration(milliseconds: 50));
          expect(requests, 2);

          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await tester.pump(const Duration(seconds: 10));
          expect(requests, 2);

          // Back on screen: caught up at once, then on the timer again.
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump(const Duration(milliseconds: 50));
          expect(requests, 3);
          await tester.pump(const Duration(seconds: 3));
          await tester.pump(const Duration(milliseconds: 50));
          expect(requests, 4);

          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient((r) {
          requests++;
          return server(r);
        }),
      );
    });
  });
}
