import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:go_bike_app/core/fix.dart';

/// About one metre north per 0.000009 degrees of latitude.
const double _metre = 0.000009;

Position at(
  double metresNorth, {
  double accuracy = 5,
  DateTime? time,
  double speed = 0,
  double heading = 0,
}) => Position(
  latitude: 15.9566 + metresNorth * _metre,
  longitude: 120.1866,
  timestamp: time ?? DateTime.now(),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: heading,
  headingAccuracy: 0,
  speed: speed,
  speedAccuracy: 0,
);

void main() {
  const fiveSeconds = Duration(seconds: 5);

  group('what the server is told', () {
    test('where, how precise, and how old the reading is', () {
      final fix = Fix(
        at(0, accuracy: 8.46, speed: 3.21, heading: 91.04),
        at: DateTime.now().subtract(const Duration(seconds: 4)),
      );

      final body = fix.toJson();
      expect(body['latitude'], 15.9566);
      expect(body['longitude'], 120.1866);
      expect(body['accuracy'], 8.5);
      expect(body['speed'], 3.2);
      expect(body['heading'], 91.0);
      expect(body['age_seconds'], 4);
    });

    test('the age comes from when the app got it, not from the reading', () {
      // A phone whose clock is an hour off stamps its readings an hour off.
      final fix = Fix(
        at(0, time: DateTime.now().subtract(const Duration(hours: 1))),
      );

      expect(fix.toJson()['age_seconds'], 0);
    });

    test('a last-known position keeps its real age', () {
      final fix = Fix.lastKnown(
        at(0, time: DateTime.now().subtract(const Duration(minutes: 40))),
      );

      expect(fix.toJson()['age_seconds'], closeTo(2400, 2));
    });

    test('a last-known position from the future is taken as just measured', () {
      final fix = Fix.lastKnown(
        at(0, time: DateTime.now().add(const Duration(minutes: 5))),
      );

      expect(fix.toJson()['age_seconds'], 0);
    });

    test('a number the phone does not have is left out, not sent as NaN', () {
      final body = Fix(at(0, speed: double.nan)).toJson();

      expect(body['speed'], isNull);
    });
  });

  group('when a reading is worth sending', () {
    test('the first one always is', () {
      expect(
        Fix.worthSending(Fix(at(0)), sent: null, sinceSent: Duration.zero),
        isTrue,
      );
    });

    test('a real move is sent at once', () {
      final sent = Fix(at(0));

      expect(
        Fix.worthSending(Fix(at(20)), sent: sent, sinceSent: fiveSeconds),
        isTrue,
      );
    });

    test('standing still waits for the heartbeat', () {
      final sent = Fix(at(0));
      final wobble = Fix(at(3));

      expect(
        Fix.worthSending(wobble, sent: sent, sinceSent: fiveSeconds),
        isFalse,
      );
      expect(
        Fix.worthSending(
          wobble,
          sent: sent,
          sinceSent: const Duration(seconds: 15),
        ),
        isTrue,
      );
    });

    test('a jump inside the phone\'s own error is not a move', () {
      final sent = Fix(at(0, accuracy: 40));
      // Indoors: 30 m away, but the phone is only sure to within 40 m.
      final drift = Fix(at(30, accuracy: 40));

      expect(
        Fix.worthSending(drift, sent: sent, sinceSent: fiveSeconds),
        isFalse,
      );
    });

    test('the same spot, but much surer of it, is sent', () {
      final sent = Fix(at(0, accuracy: 60));

      expect(
        Fix.worthSending(
          Fix(at(2, accuracy: 8)),
          sent: sent,
          sinceSent: fiveSeconds,
        ),
        isTrue,
      );
    });

    test('the very reading already sent is not sent twice', () {
      final sent = Fix(at(0));

      expect(
        Fix.worthSending(sent, sent: sent, sinceSent: fiveSeconds),
        isFalse,
      );
    });
  });

  group('the better of two readings', () {
    test('the more precise one', () {
      final rough = Fix(at(0, accuracy: 80));
      final sharp = Fix(at(0, accuracy: 6));

      expect(Fix.better(rough, sharp), same(sharp));
      expect(Fix.better(sharp, rough), same(sharp));
    });

    test('the later one when they are as precise as each other', () {
      final first = Fix(at(0));
      final second = Fix(at(1));

      expect(Fix.better(first, second), same(second));
    });

    test('a recent rough one over a precise one from minutes ago', () {
      final old = Fix(
        at(0, accuracy: 4),
        at: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      final recent = Fix(at(50, accuracy: 30));

      expect(Fix.better(old, recent), same(recent));
      expect(Fix.better(recent, old), same(recent));
    });

    test('whichever there is', () {
      final only = Fix(at(0));

      expect(Fix.better(null, only), same(only));
      expect(Fix.better(only, null), same(only));
      expect(Fix.better(null, null), isNull);
    });
  });
}
