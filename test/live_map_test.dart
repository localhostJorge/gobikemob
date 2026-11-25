import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_bike_app/core/live_map.dart';
import 'package:go_bike_app/screens/live_map_screen.dart';

void main() {
  group('reading the map answer', () {
    test('reads the town and each GoBiker\'s barangay', () {
      final data = LiveMapData.fromJson({
        'barangay': 'Poblacion',
        'town': 'Bugallon',
        'gobikers': [
          {
            'id': 2,
            'name': 'Jose Lim',
            'latitude': 15.95,
            'longitude': 120.18,
            'status': 'active',
            'barangay': 'Hacienda',
          },
        ],
        'sos': [],
      });

      expect(data.barangay, 'Poblacion');
      expect(data.town, 'Bugallon');
      expect(data.gobikers.single.barangay, 'Hacienda');
    });

    test('an older server sends no town and no barangays', () {
      final data = LiveMapData.fromJson({
        'barangay': 'Poblacion',
        'gobikers': [
          {'id': 2, 'name': 'Jose Lim', 'latitude': 15.95, 'longitude': 120.18},
        ],
      });

      expect(data.town, isNull);
      expect(data.gobikers.single.barangay, isNull);
      expect(data.sos, isEmpty);
    });
  });

  group('the card on top of the map', () {
    Future<void> show(
      WidgetTester tester, {
      String? town,
      String? barangay,
      required bool isGobiker,
      required int count,
      int openSos = 0,
    }) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveMapInfoBar(
            town: town,
            barangay: barangay,
            isGobiker: isGobiker,
            gobikersCount: count,
            openSosCount: openSos,
          ),
        ),
      ),
    );

    testWidgets('a GoBiker sees the town and the other GoBikers in it', (
      tester,
    ) async {
      await show(
        tester,
        town: 'Bugallon',
        barangay: 'Poblacion',
        isGobiker: true,
        count: 2,
        openSos: 1,
      );
      expect(find.text('Bugallon'), findsOneWidget);
      expect(
        find.text('2 other GoBikers online · 1 SOS assigned to you'),
        findsOneWidget,
      );
    });

    testWidgets('a resident is told how many GoBikers are online', (
      tester,
    ) async {
      await show(
        tester,
        town: 'Bugallon',
        barangay: 'Poblacion',
        isGobiker: false,
        count: 1,
      );
      expect(find.text('1 GoBiker online'), findsOneWidget);
      expect(find.textContaining('other'), findsNothing);
    });

    testWidgets('without a town it falls back to the barangay', (tester) async {
      await show(tester, barangay: 'Poblacion', isGobiker: false, count: 0);
      expect(find.text('Barangay Poblacion'), findsOneWidget);
      expect(find.text('0 GoBikers online'), findsOneWidget);
    });

    testWidgets('with no barangay at all it asks for one', (tester) async {
      await show(tester, isGobiker: true, count: 0);
      expect(find.text('Live Map'), findsOneWidget);
      expect(
        find.text('Set your barangay in your profile to see who is nearby.'),
        findsOneWidget,
      );
    });
  });
}
