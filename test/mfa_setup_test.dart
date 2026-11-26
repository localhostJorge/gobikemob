import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:go_bike_app/core/auth_service.dart';
import 'package:go_bike_app/screens/mfa_setup_screen.dart';
import 'package:go_bike_app/widgets/two_step_login_tile.dart';

const _secret = 'JBSWY3DPEHPK3PXP';
const _code = '123456';
final _backupCodes = [for (var i = 0; i < 10; i++) 'ab${i}d-12${i}4'];
final _newBackupCodes = [for (var i = 0; i < 10; i++) 'zz${i}y-98${i}7'];

/// The signed-in account's two-step login routes, as the Laravel API answers.
class FakeServer {
  bool mfaOn = false;
  bool sendOtpauthUrl = true;
  bool setupFails = false;
  final List<http.Request> requests = [];

  List<http.Request> to(String path) =>
      requests.where((r) => r.url.path.endsWith(path)).toList();

  Map<String, dynamic> body(http.Request r) =>
      jsonDecode(r.body) as Map<String, dynamic>;

  Map<String, dynamic> get user => {
    'id': 7,
    'name': 'Maria Santos',
    'email': 'maria@example.com',
    'role': 'User',
    'mfa_enabled': mfaOn,
  };

  Future<http.Response> handle(http.Request r) async {
    requests.add(r);
    const json = {'content-type': 'application/json'};
    http.Response reply(Object body, [int status = 200]) =>
        http.Response(jsonEncode(body), status, headers: json);
    http.Response wrong(String message) => reply({
      'message': message,
      'errors': {
        'code': [message],
      },
    }, 422);
    final path = r.url.path;

    if (path.endsWith('/mobile/login')) {
      return reply({'token': 'test-token', 'user': user});
    }
    if (r.headers['Authorization'] != 'Bearer test-token') {
      return reply({'message': 'Unauthenticated.'}, 401);
    }
    if (path.endsWith('/mobile/mfa/setup')) {
      if (setupFails) {
        return reply({'message': 'Two-step login is already on.'}, 422);
      }
      return reply({
        'message': 'Add this key to your authenticator app.',
        'secret': _secret,
        if (sendOtpauthUrl)
          'otpauth_url':
              'otpauth://totp/Go%20Bike:maria%40example.com?secret=$_secret',
      });
    }
    final code = r.body.isEmpty ? null : body(r)['code'];
    if (path.endsWith('/mobile/mfa/verify')) {
      if (code != _code) {
        return wrong(
          'That code is wrong. Try the newest code in your authenticator app.',
        );
      }
      mfaOn = true;
      // The server also sends the user back; the app copes without it too.
      return reply({
        'message': 'Two-step login is on.',
        'backup_codes': _backupCodes,
      });
    }
    if (path.endsWith('/mobile/mfa/disable')) {
      if (code != _code) return wrong('That code is wrong.');
      mfaOn = false;
      return reply({'message': 'Two-step login is off.', 'user': user});
    }
    if (path.endsWith('/mobile/mfa/backup-codes')) {
      if (code != _code) return wrong('That code is wrong.');
      return reply({'backup_codes': _newBackupCodes});
    }
    return reply({}, 404);
  }
}

void main() {
  late FakeServer server;
  String? copied;

  Future<void> run(Future<void> Function() body) =>
      http.runWithClient(body, () => MockClient(server.handle));

  // Signs in for real (outside the widget test's fake clock: the phone's
  // secure storage only answers in real time), with two-step login [on] or off.
  Future<void> signIn({bool on = false}) {
    server.mfaOn = on;
    return run(() async {
      final result = await AuthService.instance.login(
        email: 'maria@example.com',
        password: 'secret-password',
        remember: false,
      );
      expect(result.ok, isTrue);
      server.requests.clear();
    });
  }

  setUp(() async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    server = FakeServer();
    copied = null;
  });

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  /// Lets a toast run out.
  Future<void> pastToasts(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  /// The Profile's Account card, as on the resident's Profile tab.
  Widget settings() => const MaterialApp(
    home: Scaffold(body: Column(children: [TwoStepLoginSettings()])),
  );

  bool switchIsOn(WidgetTester tester) =>
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value;

  group('the Two-step login setup page', () {
    testWidgets('shows the key to add to the authenticator app', (
      tester,
    ) async {
      await phone(tester);
      await tester.runAsync(signIn);
      await run(() async {
        await tester.pumpWidget(const MaterialApp(home: MfaSetupScreen()));
        await tester.pumpAndSettle();

        expect(server.to('/api/mobile/mfa/setup').single.method, 'POST');
        expect(find.text('Two-step login'), findsOneWidget);
        expect(
          find.text('1. Add Go Bike to your authenticator app'),
          findsOneWidget,
        );
        expect(find.text(_secret), findsOneWidget);
        expect(find.text('Open in authenticator app'), findsOneWidget);
        expect(find.text('2. Enter the code it shows'), findsOneWidget);

        await tap(tester, 'Copy key');
        expect(copied, _secret);
        expect(find.text('Setup key copied.'), findsOneWidget);
        await pastToasts(tester);
      });
    });

    testWidgets('has no Open button when the server sends no link', (
      tester,
    ) async {
      await phone(tester);
      await tester.runAsync(signIn);
      server.sendOtpauthUrl = false;
      await run(() async {
        await tester.pumpWidget(const MaterialApp(home: MfaSetupScreen()));
        await tester.pumpAndSettle();
        expect(find.text(_secret), findsOneWidget);
        expect(find.text('Copy key'), findsOneWidget);
        expect(find.text('Open in authenticator app'), findsNothing);
      });
    });

    testWidgets('offers to try again when the setup could not start', (
      tester,
    ) async {
      await phone(tester);
      await tester.runAsync(signIn);
      server.setupFails = true;
      await run(() async {
        await tester.pumpWidget(const MaterialApp(home: MfaSetupScreen()));
        await tester.pumpAndSettle();
        expect(find.text('Two-step login is already on.'), findsOneWidget);
        expect(find.text(_secret), findsNothing);

        server.setupFails = false;
        await tap(tester, 'Retry');
        expect(find.text(_secret), findsOneWidget);
        expect(server.to('/mfa/setup'), hasLength(2));
      });
    });

    testWidgets('turns it on with a right code and shows the backup codes '
        'once', (tester) async {
      await phone(tester);
      await tester.runAsync(signIn);
      await run(() async {
        await tester.pumpWidget(settings());
        await tester.pumpAndSettle();
        expect(switchIsOn(tester), isFalse);
        expect(find.text('New backup codes'), findsNothing);

        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        expect(find.byType(MfaSetupScreen), findsOneWidget);

        // Checked on the phone first.
        await tap(tester, 'Turn on');
        expect(
          find.text('Enter the 6 digits from your authenticator app'),
          findsOneWidget,
        );
        expect(server.to('/mfa/verify'), isEmpty);

        // A wrong code: says what the server said.
        await tester.enterText(find.byType(TextFormField), '000000');
        await tap(tester, 'Turn on');
        expect(
          find.text(
            'That code is wrong. Try the newest code in your '
            'authenticator app.',
          ),
          findsOneWidget,
        );
        expect(AuthService.instance.currentUser?.mfaEnabled, isFalse);

        // The right one.
        await tester.enterText(find.byType(TextFormField), _code);
        await tap(tester, 'Turn on');
        expect(server.body(server.to('/mfa/verify').last), {'code': _code});
        expect(find.text('Save your backup codes'), findsOneWidget);
        for (final code in _backupCodes) {
          expect(find.text(code), findsOneWidget);
        }
        expect(AuthService.instance.currentUser?.mfaEnabled, isTrue);

        // They are shown only once: Back does not leave.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Save your backup codes'), findsOneWidget);
        expect(find.byTooltip('Back'), findsNothing);

        await tap(tester, 'Copy all');
        expect(copied, _backupCodes.join('\n'));
        await pastToasts(tester);

        await tap(tester, 'I saved them');
        expect(find.byType(MfaSetupScreen), findsNothing);
        expect(find.text('Two-step login is on.'), findsOneWidget);
        expect(switchIsOn(tester), isTrue);
        expect(find.text('New backup codes'), findsOneWidget);
        await pastToasts(tester);
      });
    });
  });

  group('the Two-step login switch, while it is on', () {
    testWidgets('turns it off with a code', (tester) async {
      await phone(tester);
      await tester.runAsync(() => signIn(on: true));
      await run(() async {
        await tester.pumpWidget(settings());
        await tester.pumpAndSettle();
        expect(switchIsOn(tester), isTrue);

        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        expect(find.text('Turn off two-step login?'), findsOneWidget);

        // Cancel keeps it on and asks nothing.
        await tap(tester, 'Cancel');
        expect(switchIsOn(tester), isTrue);
        expect(server.requests, isEmpty);

        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), '000000');
        await tap(tester, 'Turn off');
        expect(find.text('That code is wrong.'), findsOneWidget);
        expect(switchIsOn(tester), isTrue);

        await tester.enterText(find.byType(TextFormField), _code);
        await tap(tester, 'Turn off');
        final sent = server.to('/api/mobile/mfa/disable');
        expect(sent, hasLength(2));
        expect(sent.last.method, 'POST');
        expect(server.body(sent.last), {'code': _code});
        expect(find.text('Turn off two-step login?'), findsNothing);
        expect(find.text('Two-step login is off.'), findsOneWidget);
        expect(switchIsOn(tester), isFalse);
        expect(AuthService.instance.currentUser?.mfaEnabled, isFalse);
        expect(find.text('New backup codes'), findsNothing);
        await pastToasts(tester);
      });
    });

    testWidgets('gets new backup codes with a code', (tester) async {
      await phone(tester);
      await tester.runAsync(() => signIn(on: true));
      await run(() async {
        await tester.pumpWidget(settings());
        await tester.pumpAndSettle();

        await tap(tester, 'New backup codes');
        expect(find.text('Get new codes'), findsOneWidget);
        await tester.enterText(find.byType(TextFormField), '000000');
        await tap(tester, 'Get new codes');
        expect(find.text('That code is wrong.'), findsOneWidget);

        await tester.enterText(find.byType(TextFormField), _code);
        await tap(tester, 'Get new codes');
        final sent = server.to('/api/mobile/mfa/backup-codes');
        expect(sent.last.method, 'POST');
        expect(server.body(sent.last), {'code': _code});

        expect(find.text('Your backup codes'), findsOneWidget);
        for (final code in _newBackupCodes) {
          expect(find.text(code), findsOneWidget);
        }
        // Not closed by a tap outside.
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        expect(find.text('Your backup codes'), findsOneWidget);

        await tap(tester, 'I saved them');
        expect(find.text('Your backup codes'), findsNothing);
        expect(switchIsOn(tester), isTrue);
      });
    });
  });
}
