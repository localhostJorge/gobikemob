import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_bike_app/core/app_navigator.dart';

void main() {
  late bool vibrated;

  setUp(() {
    vibrated = false;
    vibrateUrgently = () async => vibrated = true;
  });

  testWidgets('the emergency the admin sent can be accepted or declined', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(navigatorKey: appNavigatorKey, home: const Scaffold()),
    );

    final accepted = showSosAssignedAlert(
      residentName: 'Ana Reyes',
      place: 'Poblacion · Beside the chapel',
    );
    await tester.pumpAndSettle();

    expect(find.text('Emergency assigned to you'), findsOneWidget);
    expect(
      find.textContaining('Ana Reyes needs help at Poblacion'),
      findsOneWidget,
    );
    expect(vibrated, isTrue);

    // There is no putting it off: accept it or say you can't.
    expect(find.text('Later'), findsNothing);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is ButtonStyleButton),
      findsNWidgets(2),
    );

    // Tapping the darkened background does not make it go away...
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.text('Emergency assigned to you'), findsOneWidget);

    // ...and neither does the back button.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Emergency assigned to you'), findsOneWidget);

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    // Accept is what sends the GoBiker to the map, on the resident's location.
    expect(await accepted, SosAlertChoice.accept);
    expect(find.text('Emergency assigned to you'), findsNothing);
  });

  testWidgets('says where to go even when the resident gave no place', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(navigatorKey: appNavigatorKey, home: const Scaffold()),
    );

    final accepted = showSosAssignedAlert(residentName: 'Ben Cruz', place: '');
    await tester.pumpAndSettle();

    expect(
      find.text('Ben Cruz needs help. You are the GoBiker sent to respond.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(await accepted, SosAlertChoice.accept);
  });
}
