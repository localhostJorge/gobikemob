import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_bike_app/core/live_map.dart';
import 'package:go_bike_app/core/theme.dart';
import 'package:go_bike_app/widgets/assigned_sos_card.dart';
import 'package:latlong2/latlong.dart';

final _sent = DateTime(2026, 11, 25, 9);

AssignedSos _sos({String? mobile = '09171234567', bool pin = true}) =>
    AssignedSos(
      id: 7,
      status: 'responding',
      residentName: 'Maria Concepcion Dela Cruz-Villanueva',
      address: 'Purok 3, Barangay Salomague Norte',
      landmark: 'beside the green sari-sari store',
      mobile: mobile,
      description:
          'My father fell in the kitchen and cannot stand up. He is 78 '
          'and has diabetes. Please come quickly, the gate is open.',
      latitude: pin ? 15.96 : null,
      longitude: pin ? 120.19 : null,
      createdAt: _sent,
    );

Future<void> _pump(
  WidgetTester tester,
  AssignedSos sos, {
  double width = 320,
  double textScale = 1.3,
  VoidCallback? onDirections,
  VoidCallback? onResolve,
  VoidCallback? onDecline,
}) async {
  tester.view.physicalSize = Size(width * 3, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 800),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: AssignedSosCard(
              sos: sos,
              from: const LatLng(15.95, 120.18),
              now: _sent.add(const Duration(minutes: 6)),
              onDirections: onDirections ?? () {},
              onResolve: onResolve ?? () {},
              onDecline: onDecline ?? () {},
            ),
          ),
        ),
      ),
    ),
  );
}

/// The height of one line of [label] as it is drawn.
double _lineHeight(WidgetTester tester, String label) {
  final para = tester.renderObject<RenderParagraph>(find.text(label));
  return para.getFullHeightForCaret(const TextPosition(offset: 0));
}

void main() {
  testWidgets('on a narrow phone with large text, no label wraps', (
    tester,
  ) async {
    await _pump(tester, _sos());
    expect(tester.takeException(), isNull); // nothing overflowed

    for (final label in ['Directions', 'Resolve', "Can't respond? Decline"]) {
      expect(find.text(label), findsOneWidget);
      final box = tester.getSize(find.text(label));
      expect(
        box.height,
        lessThanOrEqualTo(_lineHeight(tester, label) + 0.5),
        reason: '"$label" is on one line',
      );
    }
    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    expect(find.text('SOS · Responding'), findsOneWidget);
    expect(find.text('6 min ago'), findsOneWidget);
    expect(find.textContaining('km away'), findsOneWidget);
  });

  testWidgets('the buttons are 48 dp tall', (tester) async {
    await _pump(tester, _sos(), textScale: 1);
    for (final label in ['Directions', 'Resolve']) {
      final button = find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );
      expect(tester.getSize(button.first).height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('each button does its own thing', (tester) async {
    final tapped = <String>[];
    await _pump(
      tester,
      _sos(),
      onDirections: () => tapped.add('directions'),
      onResolve: () => tapped.add('resolve'),
      onDecline: () => tapped.add('decline'),
    );
    await tester.tap(find.text('Directions'));
    await tester.tap(find.text('Resolve'));
    await tester.tap(find.text("Can't respond? Decline"));
    expect(tapped, ['directions', 'resolve', 'decline']);
  });

  testWidgets('no call button without a number, no Directions without a pin', (
    tester,
  ) async {
    var directions = 0;
    await _pump(
      tester,
      _sos(mobile: null, pin: false),
      onDirections: () => directions++,
    );
    expect(find.byIcon(Icons.call_rounded), findsNothing);
    expect(find.textContaining('km away'), findsNothing);
    await tester.tap(find.text('Directions'));
    expect(directions, 0);
  });
}
