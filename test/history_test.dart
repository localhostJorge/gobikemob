import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_bike_app/core/resident_sos.dart';
import 'package:go_bike_app/screens/patient/history_screen.dart';

SosEntry _sos(int id, String status) => SosEntry.fromJson({
  'id': id,
  'status': status,
  'municipality': 'Bugallon',
  'barangay': 'Salomague Sur',
  'landmark': 'bahay',
  'created_at': DateTime.now().toUtc().toIso8601String(),
});

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: HistoryTab())),
  );
}

void main() {
  tearDown(() => ResidentSos.instance.requests = const []);

  testWidgets('past SOS requests are in History, with their status', (
    tester,
  ) async {
    ResidentSos.instance.requests = [_sos(1, 'resolved')];
    await _pump(tester);

    expect(find.text('SOS request'), findsOneWidget);
    expect(find.text('Salomague Sur · bahay'), findsOneWidget);
    expect(find.text('Resolved'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    // Something finished to clear: the Clear button is offered.
    expect(find.text('Clear'), findsOneWidget);
  });

  testWidgets('nothing finished means nothing to clear', (tester) async {
    ResidentSos.instance.requests = [_sos(2, 'sent')];
    await _pump(tester);

    expect(find.text('Waiting for response'), findsOneWidget);
    expect(find.text('Clear'), findsNothing);
  });

  testWidgets('filters use plain words', (tester) async {
    await _pump(tester);

    for (final label in ['All', 'Check-ups', 'Home visits', 'SOS']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Nothing here yet'), findsOneWidget);
  });
}
