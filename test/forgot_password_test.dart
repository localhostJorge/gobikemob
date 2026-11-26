import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:go_bike_app/core/auth_service.dart';
import 'package:go_bike_app/screens/forgot_password_screen.dart';
import 'package:go_bike_app/screens/login_screen.dart';

const _generic = 'If that email has an account, we sent a code.';

/// The two "forgot password" routes, as the Laravel API answers them.
class FakeServer {
  /// The code the last email had in it.
  String code = '123456';
  final List<http.Request> requests = [];

  List<http.Request> to(String path) =>
      requests.where((r) => r.url.path.endsWith(path)).toList();

  Map<String, dynamic> body(http.Request r) =>
      jsonDecode(r.body) as Map<String, dynamic>;

  Future<http.Response> handle(http.Request r) async {
    requests.add(r);
    const json = {'content-type': 'application/json'};
    http.Response reply(Object body, [int status = 200]) =>
        http.Response(jsonEncode(body), status, headers: json);

    if (r.url.path.endsWith('/mobile/password/forgot')) {
      // The same answer whether or not the email has an account.
      return reply({'message': _generic});
    }
    if (r.url.path.endsWith('/mobile/password/reset')) {
      final sent = body(r);
      if (sent['code'] != code) {
        return reply({
          'message': 'This code is invalid or has expired.',
          'errors': {
            'code': ['This code is invalid or has expired.'],
          },
        }, 422);
      }
      if (sent['password'] != sent['password_confirmation']) {
        return reply({
          'message': 'The password field confirmation does not match.',
          'errors': {
            'password': ['The password field confirmation does not match.'],
          },
        }, 422);
      }
      return reply({'message': 'Your password has been changed.'});
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

  Finder field(String hint) => find.widgetWithText(TextFormField, hint);

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  group('AuthService', () {
    test('asks for a code by email and gets the same answer for anyone', () {
      return run(() async {
        final result = await AuthService.instance.forgotPassword(
          '  maria@example.com ',
        );
        expect(result.ok, isTrue);
        expect(result.message, _generic);
        final sent = server.to('/api/mobile/password/forgot').single;
        expect(sent.method, 'POST');
        expect(server.body(sent), {'email': 'maria@example.com'});
      });
    });

    test('sends the code with the new password', () {
      return run(() async {
        final result = await AuthService.instance.resetPassword(
          email: 'maria@example.com',
          code: ' 123456 ',
          password: 'new-password',
          passwordConfirmation: 'new-password',
        );
        expect(result.ok, isTrue);
        expect(server.body(server.to('/api/mobile/password/reset').single), {
          'email': 'maria@example.com',
          'code': '123456',
          'password': 'new-password',
          'password_confirmation': 'new-password',
        });
      });
    });

    test('a wrong or expired code is an error on the code field', () {
      return run(() async {
        final result = await AuthService.instance.resetPassword(
          email: 'maria@example.com',
          code: '000000',
          password: 'new-password',
          passwordConfirmation: 'new-password',
        );
        expect(result.ok, isFalse);
        expect(result.field, 'code');
        expect(result.message, 'That code is wrong or has expired.');
      });
    });

    test('a password the server refuses is an error on the password', () {
      return run(() async {
        final result = await AuthService.instance.resetPassword(
          email: 'maria@example.com',
          code: '123456',
          password: 'new-password',
          passwordConfirmation: 'other-password',
        );
        expect(result.ok, isFalse);
        expect(result.field, 'password');
        expect(
          result.message,
          'The password field confirmation does not match.',
        );
      });
    });
  });

  group('the Forgot password page', () {
    testWidgets('changes the password, then Login asks to sign in again', (
      tester,
    ) async {
      await phone(tester);
      await run(() async {
        await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
        await tester.pumpAndSettle();

        // The email typed on Login comes along.
        await tester.enterText(field('name@email.com'), 'maria@example.com');
        await tap(tester, 'Forgot password?');
        expect(find.byType(ForgotPasswordScreen), findsOneWidget);
        expect(find.text('Forgot password'), findsOneWidget);
        expect(find.text('maria@example.com'), findsOneWidget);

        await tap(tester, 'Send code');
        expect(server.to('/password/forgot'), hasLength(1));
        expect(find.text('Enter the code'), findsOneWidget);
        expect(find.text(_generic), findsOneWidget);
        expect(
          find.text('Changing your password signs you out on every phone.'),
          findsOneWidget,
        );

        // A wrong code.
        await tester.enterText(field('123456'), '654321');
        await tester.enterText(field('At least 8 characters'), 'new-password');
        await tester.enterText(
          field('Retype your new password'),
          'new-password',
        );
        await tap(tester, 'Change password');
        expect(find.text('That code is wrong or has expired.'), findsOneWidget);
        expect(find.byType(ForgotPasswordScreen), findsOneWidget);

        // The right one: back to Login with the email filled in.
        await tester.enterText(find.byType(TextFormField).first, server.code);
        await tap(tester, 'Change password');
        expect(find.byType(ForgotPasswordScreen), findsNothing);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(
          find.text('Password changed. Sign in with your new password.'),
          findsOneWidget,
        );
        expect(find.text('maria@example.com'), findsOneWidget);
        expect(server.to('/password/reset'), hasLength(2));
      });
    });

    testWidgets('lets a new code be sent only after a minute', (tester) async {
      await phone(tester);
      await run(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ForgotPasswordScreen(email: 'maria@example.com'),
          ),
        );
        await tester.pumpAndSettle();
        await tap(tester, 'Send code');

        expect(find.text('Send a new code in 60s'), findsOneWidget);
        TextButton resend() => tester.widget<TextButton>(
          find.ancestor(
            of: find.textContaining('Send a new code'),
            matching: find.byType(TextButton),
          ),
        );
        expect(resend().onPressed, isNull);

        await tester.pump(const Duration(seconds: 30));
        expect(find.text('Send a new code in 30s'), findsOneWidget);
        expect(resend().onPressed, isNull);

        await tester.pump(kResendWait);
        expect(find.text('Send a new code'), findsOneWidget);
        expect(resend().onPressed, isNotNull);

        await tester.tap(find.text('Send a new code'));
        await tester.pump();
        await tester.pump();
        expect(server.to('/password/forgot'), hasLength(2));
        expect(find.text('We sent a new code.'), findsOneWidget);
        expect(find.text('Send a new code in 60s'), findsOneWidget);

        // Past the toast and the new wait.
        await tester.pump(const Duration(seconds: 61));
        await tester.pumpAndSettle();
      });
    });

    testWidgets('Back on the code step goes back to the email step', (
      tester,
    ) async {
      await phone(tester);
      await run(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ForgotPasswordScreen(email: 'maria@example.com'),
          ),
        );
        await tester.pumpAndSettle();
        await tap(tester, 'Send code');
        expect(find.text('Enter the code'), findsOneWidget);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Forgot password'), findsOneWidget);
        expect(find.text('Send code'), findsOneWidget);

        await tester.pump(kResendWait);
      });
    });

    testWidgets('checks the email before asking the server', (tester) async {
      await phone(tester);
      await run(() async {
        await tester.pumpWidget(
          const MaterialApp(home: ForgotPasswordScreen()),
        );
        await tester.pumpAndSettle();
        await tap(tester, 'Send code');
        expect(find.text('Enter your email'), findsOneWidget);

        await tester.enterText(find.byType(TextFormField), 'maria');
        await tap(tester, 'Send code');
        expect(find.text('Enter a valid email'), findsOneWidget);
        expect(server.requests, isEmpty);
      });
    });
  });
}
