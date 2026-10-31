import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_bike_app/screens/create_account_screen.dart';

void main() {
  testWidgets('asks a GoBiker for a profile photo, but never a resident', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: CreateAccountScreen()));
    await tester.pumpAndSettle();

    // Resident is the default: no photo is asked for.
    expect(find.text('Profile Photo'), findsNothing);
    expect(find.textContaining('Profile Photo Requirements'), findsNothing);

    await tester.tap(find.text('GoBiker'));
    await tester.pumpAndSettle();

    expect(find.text('Profile Photo'), findsOneWidget);
    expect(find.text('Required'), findsOneWidget);
    // The wording the GoBiker is given, as the admin asked for it.
    expect(
      find.textContaining('Please upload a clear and formal photo of yourself'),
      findsOneWidget,
    );
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);

    // Switching back to Resident puts it away again.
    await tester.tap(find.text('Resident'));
    await tester.pumpAndSettle();
    expect(find.text('Profile Photo'), findsNothing);
  });

  testWidgets('a GoBiker cannot submit the form without a photo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: CreateAccountScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('GoBiker'));
    await tester.pumpAndSettle();

    // Everything else filled in: only the photo is missing.
    await tester.enterText(find.byType(TextFormField).at(0), 'Juan Dela Cruz');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'juan@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), '09171234567');
    await tester.pumpAndSettle();

    final button = find.widgetWithText(ElevatedButton, 'Create Account');
    expect(
      tester.widget<ElevatedButton>(button).onPressed,
      isNull,
      reason: 'Create Account must stay disabled until a photo is added',
    );
  });
}
