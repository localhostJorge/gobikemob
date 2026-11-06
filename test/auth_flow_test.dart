import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:go_bike_app/core/auth_service.dart';
import 'package:go_bike_app/core/first_run.dart';
import 'package:go_bike_app/core/theme.dart';
import 'package:go_bike_app/screens/create_account_screen.dart';
import 'package:go_bike_app/screens/login_screen.dart';
import 'package:go_bike_app/screens/patient/profile.dart';
import 'package:go_bike_app/screens/splash_screen.dart';
import 'package:go_bike_app/screens/welcome_screen.dart';
import 'package:go_bike_app/widgets/auth_widgets.dart';
import 'package:go_bike_app/widgets/loading_card.dart';

const _title = 'Every Ride Has a Purpose.';

void main() {
  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  // The splash reads the saved session from the phone's secure storage, which only answers
  // in real time, so the test lets some real time pass between its fake frames.
  Future<void> bootSplash(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump(const Duration(seconds: 2));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // the transition
  }

  // Android's system Back: neither page has a back arrow of its own.
  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  group('Get Started is for a new user only', () {
    test('is unseen until a person has been past it', () async {
      expect(await FirstRun.seen(), isFalse);
      await FirstRun.markSeen();
      expect(await FirstRun.seen(), isTrue);
    });

    testWidgets('the splash screen opens Get Started on a first run', (
      tester,
    ) async {
      await phone(tester);
      await bootSplash(tester);

      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text(_title), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('and the Login page once they have been past it', (
      tester,
    ) async {
      await phone(tester);
      await FirstRun.markSeen();
      await bootSplash(tester);

      expect(find.text(_title), findsOneWidget);
      expect(find.text('Get Started'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping Get Started, or Create an account, remembers it', (
      tester,
    ) async {
      await phone(tester);
      await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      expect(await FirstRun.seen(), isTrue);

      SharedPreferences.resetStatic();
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
      await tester.pump(const Duration(seconds: 1));
      expect(await FirstRun.seen(), isFalse);
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();
      expect(await FirstRun.seen(), isTrue);
    });

    testWidgets('the logo is the same Hero on the splash, Get Started and '
        'Login screens', (tester) async {
      await phone(tester);
      for (final home in const [
        SplashScreen(),
        WelcomeScreen(),
        LoginScreen(),
      ]) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(MaterialApp(home: home));
        await tester.pump();
        final hero = tester.widget<Hero>(
          find.ancestor(of: find.byType(AuthLogo), matching: find.byType(Hero)),
        );
        expect(hero.tag, authLogoHero, reason: '${home.runtimeType}');
        await tester.pump(const Duration(seconds: 3));
      }
    });
  });

  group('the Login page', () {
    testWidgets('says what the app is for, not "Welcome back"', (tester) async {
      await phone(tester);
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pump();

      expect(find.text(_title), findsOneWidget);
      expect(find.text('Stay connected. Stay prepared.'), findsOneWidget);
      expect(find.text('Welcome back'), findsNothing);
      expect(find.text('Log in to continue'), findsNothing);
    });

    testWidgets('still fits at 360 dp with large text', (tester) async {
      await phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: const LoginScreen(),
        ),
      );
      await tester.pump();
      expect(find.text(_title), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Back from Sign up', () {
    Future<void> openSignUp(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Sign Up'));
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();
    }

    testWidgets('goes to Login, and Back again goes to Get Started', (
      tester,
    ) async {
      await phone(tester);
      await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      expect(find.text(_title), findsOneWidget);

      await openSignUp(tester);
      expect(find.byType(CreateAccountScreen), findsOneWidget);

      await back(tester);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing); // hidden under Login

      await back(tester);
      expect(find.text('Get Started'), findsOneWidget);
    });

    testWidgets('goes to Login when Login was the first page, too', (
      tester,
    ) async {
      await phone(tester);
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pump();

      await openSignUp(tester);
      await back(tester);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(CreateAccountScreen), findsNothing);
    });

    testWidgets(
      'the "Log in" link on Sign up goes back to Login, not on top of '
      'it',
      (tester) async {
        await phone(tester);
        await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
        await tester.pump();
        await openSignUp(tester);

        await tester.ensureVisible(find.text('Log in'));
        await tester.tap(find.text('Log in'));
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(CreateAccountScreen), findsNothing);
        // Nothing is left to go back to.
        expect(
          Navigator.of(tester.element(find.byType(LoginScreen))).canPop(),
          isFalse,
        );
      },
    );

    testWidgets('from Get Started, Sign up still goes back to Get Started', (
      tester,
    ) async {
      await phone(tester);
      await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();
      await back(tester);
      expect(find.text('Get Started'), findsOneWidget);
    });
  });

  group('Logging out', () {
    const resident = AppUser(
      id: 1,
      name: 'Ana Reyes',
      email: 'ana@example.com',
      role: 'User',
      mobile: '09170001111',
      barangay: 'Poblacion',
    );

    testWidgets('the card says "Logging out..." and cannot be dismissed', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showLoggingOut(context),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Logging out...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tapAt(const Offset(2, 2)); // the barrier
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Logging out...'), findsOneWidget);
    });

    testWidgets('a resident lands on Login, not Get Started, with nothing '
        'to go back to', (tester) async {
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) =>
                  const Scaffold(body: ProfileTab(currentUser: resident)),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Log out'));
      // Not pumpAndSettle: the About row's shimmer never stops in a test.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Log out').last);
      await tester.pump();
      expect(find.text('Logging out...'), findsOneWidget); // while it works
      // Logging out talks to the phone's storage and push service, in real time.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 4)); // the toast goes away

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(_title), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
      expect(find.text('Logging out...'), findsNothing);
      expect(
        Navigator.of(tester.element(find.byType(LoginScreen))).canPop(),
        isFalse,
      );
    });
  });

  group('Light first', () {
    test('a new install is light, whatever the phone is set to', () async {
      await ThemeController.instance.load();
      expect(ThemeController.instance.themeMode, ThemeMode.light);
    });

    test('a saved choice of dark is kept', () async {
      SharedPreferences.resetStatic();
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      await ThemeController.instance.load();
      expect(ThemeController.instance.themeMode, ThemeMode.dark);

      SharedPreferences.resetStatic();
      SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
      await ThemeController.instance.load();
      expect(ThemeController.instance.themeMode, ThemeMode.light);
    });

    test('an old "system" choice becomes light', () async {
      SharedPreferences.resetStatic();
      SharedPreferences.setMockInitialValues({'theme_mode': 'system'});
      await ThemeController.instance.load();
      expect(ThemeController.instance.themeMode, ThemeMode.light);
    });
  });
}
