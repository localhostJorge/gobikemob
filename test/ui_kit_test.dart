import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_bike_app/core/appointments.dart';
import 'package:go_bike_app/core/resident_sos.dart';
import 'package:go_bike_app/core/resident_visits.dart';
import 'package:go_bike_app/screens/patient/app_colors.dart';
import 'package:go_bike_app/screens/patient/history_screen.dart';
import 'package:go_bike_app/screens/patient/settings_screen.dart';
import 'package:go_bike_app/screens/patient/skeletons.dart';
import 'package:go_bike_app/screens/patient/ui_kit.dart';

double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final hi = math.max(_luminance(a), _luminance(b));
  final lo = math.min(_luminance(a), _luminance(b));
  return (hi + 0.05) / (lo + 0.05);
}

Widget _app(Widget child, {bool reduceMotion = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(body: child),
  ),
);

void main() {
  group('palette', () {
    test('text colors are readable on white (4.5:1)', () {
      for (final c in {
        'textDark': AppColors.textDark,
        'textMuted': AppColors.textMuted,
        'redText': AppColors.redText,
        'orangeText': AppColors.orangeText,
        'greenText': AppColors.greenText,
        'blue': AppColors.blue,
      }.entries) {
        expect(
          _contrast(c.value, Colors.white),
          greaterThanOrEqualTo(4.5),
          reason: c.key,
        );
      }
    });

    test('white labels on the button red are readable (4.5:1)', () {
      expect(
        _contrast(Colors.white, AppColors.redButton),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('muted text stays readable on the page background', () {
      expect(
        _contrast(AppColors.textMuted, AppColors.background),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('skeleton', () {
    testWidgets('announces what is loading and shows its shapes', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const Skeleton(
            label: 'Loading your history',
            child: SkeletonBox(width: 100, height: 14),
          ),
        ),
      );

      expect(find.byType(SkeletonBox), findsOneWidget);
      expect(find.bySemanticsLabel('Loading your history'), findsOneWidget);
      expect(find.byType(ShaderMask), findsOneWidget); // the shimmer
    });

    testWidgets('does not shimmer when the phone asks for less motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const Skeleton(child: SkeletonBox(width: 100, height: 14)),
          reduceMotion: true,
        ),
      );

      expect(find.byType(SkeletonBox), findsOneWidget);
      expect(find.byType(ShaderMask), findsNothing);
    });

    testWidgets('LoadSwitcher shows the skeleton, then the content', (
      tester,
    ) async {
      Widget build(bool loading) => _app(
        LoadSwitcher(
          loading: loading,
          skeleton: const SkeletonBox(width: 50),
          child: const Text('Loaded'),
        ),
        reduceMotion: true,
      );

      await tester.pumpWidget(build(true));
      expect(find.byType(SkeletonBox), findsOneWidget);
      expect(find.text('Loaded'), findsNothing);

      await tester.pumpWidget(build(false));
      await tester.pump();
      expect(find.text('Loaded'), findsOneWidget);
      expect(find.byType(SkeletonBox), findsNothing);
    });
  });

  group('screens show skeletons while loading', () {
    tearDown(() {
      ResidentVisits.instance
        ..loading = false
        ..loaded = false
        ..error = null
        ..visits = const [];
      ResidentSos.instance.requests = const [];
    });

    testWidgets('History: skeleton on the first load, never on a refresh', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      ResidentVisits.instance
        ..loading = true
        ..loaded = false;
      await tester.pumpWidget(_app(const HistoryTab(), reduceMotion: true));
      expect(find.byType(HistorySkeleton), findsOneWidget);
      expect(find.text('Nothing here yet'), findsNothing);

      // Loaded once: a refresh keeps the content instead of the skeleton.
      ResidentVisits.instance
        ..loaded = true
        ..loading = true
        ..notifyListeners();
      await tester.pump();
      await tester.pump();
      expect(find.byType(HistorySkeleton), findsNothing);
      expect(find.text('Nothing here yet'), findsOneWidget);
    });

    testWidgets('a failed first load shows the error with Try again', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      ResidentVisits.instance
        ..loading = false
        ..loaded = false
        ..error = 'No connection';
      await tester.pumpWidget(_app(const HistoryTab(), reduceMotion: true));

      expect(find.text("Couldn't load this"), findsOneWidget);
      expect(find.text('No connection'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('components', () {
    testWidgets('PrimaryButton is disabled and shows progress while loading', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          PrimaryButton(
            label: 'Save changes',
            loading: true,
            onPressed: () => taps++,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Save changes'), findsNothing);
      await tester.tap(find.byType(FilledButton));
      expect(taps, 0);
    });

    testWidgets('PrimaryButton calls back when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(PrimaryButton(label: 'Save changes', onPressed: () => taps++)),
      );

      await tester.tap(find.text('Save changes'));
      expect(taps, 1);
    });

    testWidgets('showConfirm returns the choice', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showConfirm(
                context,
                title: 'Clear history?',
                message: 'This cannot be undone.',
                confirmLabel: 'Clear',
                destructive: true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Clear history?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('Settings offers 1, 2 and 3 second hold times only', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(const SettingsTab(), reduceMotion: true));

      for (final label in ['1 sec', '2 sec', '3 sec']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('5 sec'), findsNothing);
      expect(find.text('Emergency SOS'), findsOneWidget);
    });
  });

  test('stores used by the screens start empty', () {
    expect(ResidentAppointments.instance.appointments, isEmpty);
  });
}
