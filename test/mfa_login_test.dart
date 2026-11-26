import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:go_bike_app/core/auth_service.dart';
import 'package:go_bike_app/screens/login_screen.dart';

const _authCode = '123456';
const _backupCode = 'abcd-1234';

/// POST /api/mobile/login for an account with two-step login on.
class FakeServer {
  /// The role of the account; "Admin" stops on Login after signing in, so a
  /// test can see the second try go through without opening a dashboard.
  String role = 'User';
  final List<http.Request> requests = [];

  List<Map<String, dynamic>> get logins => [
    for (final r in requests)
      if (r.url.path.endsWith('/mobile/login'))
        jsonDecode(r.body) as Map<String, dynamic>,
  ];

  Future<http.Response> handle(http.Request r) async {
    requests.add(r);
    const json = {'content-type': 'application/json'};
    http.Response reply(Object body, [int status = 200]) =>
        http.Response(jsonEncode(body), status, headers: json);

    if (r.url.path.endsWith('/mobile/login')) {
      final sent = jsonDecode(r.body) as Map<String, dynamic>;
      if (sent['password'] != 'secret-password') {
        return reply({
          'message': 'These credentials do not match our records.',
          'errors': {
            'email': ['These credentials do not match our records.'],
          },
        }, 422);
      }
      final code = sent['mfa_code'];
      if (code == null) {
        return reply({
          'message': 'Enter the code from your authenticator app.',
          'mfa_required': true,
        }, 422);
      }
      if (code != _authCode && code != _backupCode) {
        return reply({
          'message': 'The code is invalid.',
          'errors': {
            'mfa_code': ['The code is invalid.'],
          },
        }, 422);
      }
      return reply({
        'token': 'test-token',
        'user': {
          'id': 7,
          'name': 'Maria Santos',
          'email': 'maria@example.com',
          'role': role,
          'mfa_enabled': true,
        },
      });
    }
    return reply({}, 404);
  }
}

void main() {
  late FakeServer server;

  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    server = FakeServer();
  });

  Future<void> run(Future<void> Function() body) =>
      http.runWithClient(body, () => MockClient(server.handle));

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  // Signing in saves (or clears) the token in the phone's secure storage, which
  // only answers in real time: let some pass between fake frames.
  Future<void> realTime(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
    }
  }

  Future<void> signIn(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'name@email.com'),
      'maria@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter your password'),
      'secret-password',
    );
    await tap(tester, 'Login');
  }

  group('AuthService.login', () {
    test('says when the account needs a code', () {
      return run(() async {
        final result = await AuthService.instance.login(
          email: 'maria@example.com',
          password: 'secret-password',
          remember: false,
        );
        expect(result.ok, isFalse);
        expect(result.mfaRequired, isTrue);
        expect(server.logins.single.containsKey('mfa_code'), isFalse);
        expect(AuthService.instance.currentUser, isNull);
      });
    });

    test('a wrong code still asks for a code', () {
      return run(() async {
        final result = await AuthService.instance.login(
          email: 'maria@example.com',
          password: 'secret-password',
          remember: false,
          mfaCode: '000000',
        );
        expect(result.ok, isFalse);
        expect(result.mfaRequired, isTrue);
        expect(result.message, 'The code is invalid.');
      });
    });

    test('signs in with the code', () {
      return run(() async {
        final result = await AuthService.instance.login(
          email: 'maria@example.com',
          password: 'secret-password',
          remember: false,
          mfaCode: ' $_authCode ',
        );
        expect(result.ok, isTrue);
        expect(result.user?.mfaEnabled, isTrue);
        expect(server.logins.single['mfa_code'], _authCode);
      });
    });

    test('a wrong password is not a code question', () {
      return run(() async {
        final result = await AuthService.instance.login(
          email: 'maria@example.com',
          password: 'wrong',
          remember: false,
        );
        expect(result.ok, isFalse);
        expect(result.mfaRequired, isFalse);
        expect(result.message, 'These credentials do not match our records.');
      });
    });
  });

  group('the Login page with two-step login on', () {
    testWidgets('asks for the code after the password', (tester) async {
      await phone(tester);
      await run(() async {
        await signIn(tester);

        expect(find.text('Two-step login'), findsOneWidget);
        expect(
          find.text('Enter the 6-digit code from your authenticator app.'),
          findsOneWidget,
        );
        expect(find.text('6-digit code'), findsOneWidget);
        expect(
          find.text(
            'Lost your phone and backup codes? Ask the admin to turn off MFA.',
          ),
          findsOneWidget,
        );
        expect(find.text('Every Ride Has a Purpose.'), findsNothing);

        // Checked on the phone first.
        await tap(tester, 'Verify');
        expect(
          find.text('Enter the 6 digits from your authenticator app'),
          findsOneWidget,
        );
        expect(server.logins, hasLength(1));

        // Wrong: stays on the code step and says so.
        await tester.enterText(find.byType(TextFormField), '000000');
        await tap(tester, 'Verify');
        expect(find.text('That code is wrong. Try again.'), findsOneWidget);
        expect(find.text('Two-step login'), findsOneWidget);
        expect(server.logins.last, {
          'email': 'maria@example.com',
          'password': 'secret-password',
          'mfa_code': '000000',
        });
      });
    });

    testWidgets('takes a backup code instead', (tester) async {
      await phone(tester);
      server.role = 'Admin';
      await run(() async {
        await signIn(tester);
        await tap(tester, 'Use a backup code');

        expect(find.text('Backup code'), findsOneWidget);
        expect(
          find.text(
            'Enter one of the backup codes you saved. Each code works once.',
          ),
          findsOneWidget,
        );
        expect(find.text('Use the code from your app'), findsOneWidget);

        await tester.enterText(find.byType(TextFormField), 'abcd');
        await tap(tester, 'Verify');
        expect(find.text('Enter a backup code like abcd-1234'), findsOneWidget);

        await tester.enterText(find.byType(TextFormField), _backupCode);
        await tester.tap(find.text('Verify'));
        await realTime(tester);
        expect(server.logins.last['mfa_code'], _backupCode);
        // Signed in; an admin account is then sent to the website.
        expect(
          find.text('Admin accounts use the web admin panel.'),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
      });
    });

    testWidgets('Back to login, and system Back, go to the password', (
      tester,
    ) async {
      await phone(tester);
      await run(() async {
        await signIn(tester);
        await tap(tester, 'Back to login');
        expect(find.text('Every Ride Has a Purpose.'), findsOneWidget);
        expect(find.text('Two-step login'), findsNothing);

        await tap(tester, 'Login');
        expect(find.text('Two-step login'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Every Ride Has a Purpose.'), findsOneWidget);
        expect(find.byType(LoginScreen), findsOneWidget);
      });
    });
  });
}
