import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_bike_app/widgets/location_dropdowns.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The location API as the server answers it: each City / Municipality has
/// exactly one municipality row of the same name.
final _api = MockClient((req) async {
  final path = req.url.path;
  final q = req.url.queryParameters;
  Object body;
  if (path.endsWith('/locations/provinces')) {
    body = {
      'provinces': [
        {'id': 1, 'name': 'Pangasinan'},
      ],
    };
  } else if (path.endsWith('/locations/cities')) {
    body = {
      'cities': [
        {'id': 10, 'name': 'Bugallon'},
        {'id': 11, 'name': 'Aguilar'},
      ],
    };
  } else if (path.endsWith('/locations/municipalities')) {
    final cityId = q['city_id'];
    body = {
      'municipalities': [
        {
          'id': cityId == '10' ? 100 : 101,
          'name': cityId == '10' ? 'Bugallon' : 'Aguilar',
        },
      ],
    };
  } else if (path.endsWith('/locations/barangays')) {
    final names = q['municipality_id'] == '100'
        ? ['Asinan', 'Poblacion']
        : ['Bayaoas', 'Pogonsili'];
    body = {
      'barangays': [
        for (final n in names) {'name': n},
      ],
    };
  } else {
    return http.Response('not found', 404);
  }
  return http.Response(jsonEncode(body), 200);
});

Future<void> _pick(WidgetTester tester, String hint, String item) async {
  // The hint sits inside the dropdown, which takes the tap: that's the point.
  await tester.tap(find.text(hint), warnIfMissed: false);
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'City / Municipality leads straight to Barangay, with no Municipality dropdown',
    (tester) async {
      await http.runWithClient(() async {
        String? chosen;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: LocationDropdowns(onChanged: (v) => chosen = v),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await _pick(tester, 'Select your province', 'Pangasinan');
        expect(find.text('City / Municipality'), findsOneWidget);

        await _pick(tester, 'Select your city or municipality', 'Aguilar');
        expect(find.text('Municipality'), findsNothing);
        expect(find.text('Select your municipality'), findsNothing);

        // Barangays of the chosen town load without any extra tap.
        await _pick(tester, 'Select your barangay', 'Pogonsili');
        expect(chosen, 'Pogonsili');

        // Switching town clears the barangay and loads the new town's list.
        await _pick(tester, 'Aguilar', 'Bugallon');
        expect(chosen, isNull);
        await _pick(tester, 'Select your barangay', 'Asinan');
        expect(chosen, 'Asinan');
      }, () => _api);
    },
  );
}
