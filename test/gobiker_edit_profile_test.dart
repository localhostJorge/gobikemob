import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:go_bike_app/core/auth_service.dart';
import 'package:go_bike_app/screens/gobiker_edit_profile_screen.dart';
import 'package:go_bike_app/screens/login_screen.dart';
import 'package:go_bike_app/widgets/brand.dart';

void main() {
  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
  });

  const gobiker = AppUser(
    id: 7,
    name: 'Maria Santos',
    email: 'maria@example.com',
    role: 'GoBiker',
    mobile: '09170001111',
    barangay: 'Poblacion',
  );

  testWidgets('editing the profile is a page of its own, not a pop-up', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: GobikerEditProfileScreen(user: gobiker)),
    );
    await tester.pump();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Edit profile'), findsOneWidget);
    for (final field in [
      'Mobile number',
      'Barangay',
      'Current password',
      'New password',
      'Confirm new password',
    ]) {
      expect(find.text(field), findsOneWidget, reason: field);
    }
    expect(find.text('09170001111'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);

    // Checked before anything is sent.
    await tester.enterText(
      find.widgetWithText(TextFormField, '09170001111'),
      '123',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    expect(find.text('Use 11 digits starting with 09'), findsOneWidget);
  });

  testWidgets('the Login page sits in the middle of a tall phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pump();

    final top = tester.getTopLeft(find.byType(RondaGoIcon)).dy;
    final bottom = tester.getBottomLeft(find.text('Sign Up')).dy;
    final middle = (top + bottom) / 2;
    // Centered in the screen (within a few points), not pinned to the top.
    expect(middle, closeTo(500, 40));
    expect(top, greaterThan(100));
  });
}
