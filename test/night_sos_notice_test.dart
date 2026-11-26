import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_bike_app/widgets/night_sos_notice.dart';

void main() {
  late NightSosChoice? result;
  late bool closed;

  Future<void> open(WidgetTester tester) async {
    closed = false;
    result = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showNightSosNotice(context);
              closed = true;
            },
            child: const Text('hold'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('hold'));
    await tester.pumpAndSettle();
  }

  testWidgets('says help may take longer, without blaming anyone', (
    tester,
  ) async {
    await open(tester);
    expect(find.text("It's late at night"), findsOneWidget);
    expect(
      find.text(
        'Help from Go Bike may take longer at this hour, as fewer GoBikers '
        "are out. If someone's life is in danger, call 911 or your local "
        'hotline now.',
      ),
      findsOneWidget,
    );
    expect(find.text('Call 911'), findsOneWidget);
    expect(find.text('Send SOS anyway'), findsOneWidget);
  });

  testWidgets('Call 911 returns call911', (tester) async {
    await open(tester);
    await tester.tap(find.text('Call 911'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, NightSosChoice.call911);
  });

  testWidgets('Send SOS anyway returns sendAnyway', (tester) async {
    await open(tester);
    await tester.tap(find.text('Send SOS anyway'));
    await tester.pumpAndSettle();
    expect(result, NightSosChoice.sendAnyway);
  });

  testWidgets('dismissing it chooses nothing', (tester) async {
    await open(tester);
    await tester.tapAt(const Offset(5, 5)); // outside the dialog
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, isNull);
  });
}
