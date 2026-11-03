import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_bike_app/widgets/bottom_gap.dart';
import 'package:go_bike_app/widgets/loading_overlay.dart';

class _Form extends StatefulWidget {
  const _Form({required this.loading, required this.onSend});
  final bool loading;
  final VoidCallback onSend;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: LoadingOverlay(
        isLoading: widget.loading,
        message: 'Signing in...',
        child: Scaffold(
          body: Column(
            children: [
              TextField(controller: _controller),
              ElevatedButton(onPressed: widget.onSend, child: const Text('Go')),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  group('LoadingOverlay', () {
    testWidgets('lets the screen be used when nothing is loading', (
      tester,
    ) async {
      var sent = 0;
      await tester.pumpWidget(_Form(loading: false, onSend: () => sent++));

      await tester.tap(find.text('Go'));
      expect(sent, 1);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('takes every tap while loading, so nothing underneath fires', (
      tester,
    ) async {
      var sent = 0;
      await tester.pumpWidget(_Form(loading: true, onSend: () => sent++));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Signing in...'), findsOneWidget);

      // The button is still drawn under the shade, but a tap on it never reaches it.
      await tester.tap(find.text('Go'), warnIfMissed: false);
      await tester.tap(find.text('Go'), warnIfMissed: false);
      expect(sent, 0);

      // Nor can the field be tapped into.
      await tester.tap(find.byType(TextField), warnIfMissed: false);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.context?.widget is EditableText,
        isFalse,
      );
    });

    testWidgets('the shade cannot be tapped away', (tester) async {
      await tester.pumpWidget(_Form(loading: true, onSend: () {}));

      await tester.tapAt(const Offset(20, 20));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('works again as soon as loading stops', (tester) async {
      var sent = 0;
      await tester.pumpWidget(_Form(loading: true, onSend: () => sent++));
      await tester.tap(find.text('Go'), warnIfMissed: false);
      expect(sent, 0);

      await tester.pumpWidget(_Form(loading: false, onSend: () => sent++));
      await tester.tap(find.text('Go'));
      expect(sent, 1);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('keeps what was typed when loading starts and stops', (
      tester,
    ) async {
      await tester.pumpWidget(_Form(loading: false, onSend: () {}));
      await tester.enterText(find.byType(TextField), 'ana@example.com');

      await tester.pumpWidget(_Form(loading: true, onSend: () {}));
      await tester.pumpWidget(_Form(loading: false, onSend: () {}));

      expect(find.text('ana@example.com'), findsOneWidget);
    });
  });

  group('bottomGap', () {
    Future<double> gapWith(
      WidgetTester tester, {
      EdgeInsets viewPadding = EdgeInsets.zero,
      EdgeInsets gestures = EdgeInsets.zero,
    }) async {
      late double gap;
      late double extra;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            viewPadding: viewPadding,
            systemGestureInsets: gestures,
          ),
          child: Builder(
            builder: (context) {
              gap = bottomGap(context);
              extra = extraBottomGap(context);
              return const SizedBox();
            },
          ),
        ),
      );
      return gap * 1000 + extra;
    }

    testWidgets('is the taller of the navigation area and the gesture strip', (
      tester,
    ) async {
      // Gesture navigation: no bar, but a 24 dp strip along the bottom.
      expect(
        await gapWith(tester, gestures: const EdgeInsets.only(bottom: 24)),
        24 * 1000 + 24,
      );
      // Three-button navigation: a 48 dp bar, no gesture strip.
      expect(
        await gapWith(tester, viewPadding: const EdgeInsets.only(bottom: 48)),
        48 * 1000 + 0,
      );
      // Both: never the sum, and never negative.
      expect(
        await gapWith(
          tester,
          viewPadding: const EdgeInsets.only(bottom: 34),
          gestures: const EdgeInsets.only(bottom: 20),
        ),
        34 * 1000 + 0,
      );
      expect(await gapWith(tester), 0);
    });
  });
}
