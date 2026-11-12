import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:go_bike_app/core/auth_service.dart';
import 'package:go_bike_app/screens/legal_screen.dart';
import 'package:go_bike_app/widgets/delete_account_sheet.dart';

/// The website's Terms as the API sends them (GET /api/legal/terms).
Map<String, dynamic> termsJson({String updated = 'November 13, 2026'}) => {
  'key': 'terms',
  'title': 'Terms & Conditions',
  'last_updated': updated,
  'url': 'https://gobikeproject.org/terms',
  'sections': [
    {
      'title': '1. Acceptance of These Terms',
      'content': 'These Terms govern your use of **the RondaGo app**.\n\nRead our [Privacy Policy](/privacy-policy).',
    },
    {
      'title': '6. Emergencies and SOS Requests',
      'content': '- **In a life-threatening emergency, call 911 first.**\n- Help depends on volunteers.\n\nEmail gobike@pydn.org.',
    },
  ],
};

class FakeServer {
  bool online = true;
  int deleteStatus = 200;
  final List<http.Request> requests = [];

  Future<http.Response> handle(http.Request r) async {
    requests.add(r);
    const json = {'content-type': 'application/json'};
    if (!online) throw http.ClientException('offline');

    if (r.url.path.endsWith('/legal/terms')) {
      return http.Response(jsonEncode(termsJson()), 200, headers: json);
    }
    if (r.url.path.endsWith('/mobile/account') && r.method == 'DELETE') {
      final body = deleteStatus == 200
          ? {'message': 'Your account has been deleted.'}
          : deleteStatus == 409
          ? {
              'message': 'You recorded check-ups, and those health records must be kept. Email gobike@pydn.org and we will close your account.',
            }
          : {
              'message': 'The password is incorrect.',
              'errors': {
                'password': ['The password is incorrect.'],
              },
            };
      return http.Response(jsonEncode(body), deleteStatus, headers: json);
    }
    return http.Response('{}', 404, headers: json);
  }
}

void main() {
  late FakeServer server;

  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    server = FakeServer();
  });

  Future<void> run(WidgetTester tester, Future<void> Function() body) =>
      http.runWithClient(body, () => MockClient(server.handle));

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Finder rich(String text) => find.textContaining(text, findRichText: true);

  group('Terms & Conditions and Privacy Policy', () {
    testWidgets('shows the text published on the website', (tester) async {
      await phone(tester);
      await run(tester, () async {
        await tester.pumpWidget(
          const MaterialApp(home: LegalScreen(type: LegalType.terms)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Terms & Conditions'), findsOneWidget);
        expect(find.text('Last updated: November 13, 2026'), findsOneWidget);
        expect(find.text('1. Acceptance of These Terms'), findsOneWidget);
        expect(find.text('6. Emergencies and SOS Requests'), findsOneWidget);
        // Bold, links and list items are shown as text, without the markup.
        expect(rich('govern your use of the RondaGo app.'), findsOneWidget);
        expect(rich('**'), findsNothing);
        expect(rich('Privacy Policy'), findsOneWidget);
        expect(rich('](/privacy-policy)'), findsNothing);
        expect(rich('call 911 first'), findsOneWidget);
        expect(find.text('•'), findsNWidgets(2));
        expect(rich('gobike@pydn.org'), findsOneWidget);
        expect(find.text('Open on the website'), findsOneWidget);

        expect(server.requests.single.url.path, endsWith('/api/legal/terms'));
      });
    });

    testWidgets('shows the copy saved on the phone when offline', (
      tester,
    ) async {
      await phone(tester);
      SharedPreferences.setMockInitialValues({
        'legal_doc_terms': jsonEncode(termsJson(updated: 'November 1, 2026')),
      });
      server.online = false;

      await run(tester, () async {
        await tester.pumpWidget(
          const MaterialApp(home: LegalScreen(type: LegalType.terms)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Last updated: November 1, 2026'), findsOneWidget);
        expect(
          find.text('You are offline. This is the copy saved on your phone.'),
          findsOneWidget,
        );
        expect(find.text('1. Acceptance of These Terms'), findsOneWidget);
      });
    });

    testWidgets('offers to try again when nothing could be loaded', (
      tester,
    ) async {
      await phone(tester);
      server.online = false;

      await run(tester, () async {
        await tester.pumpWidget(
          const MaterialApp(home: LegalScreen(type: LegalType.privacy)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Privacy Policy'), findsOneWidget);
        expect(find.text("Couldn't load this page"), findsOneWidget);

        server.online = true;
        server.requests.clear();
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();
        expect(server.requests.single.url.path, endsWith('/api/legal/privacy'));
      });
    });

    testWidgets('saves the latest copy for next time', (tester) async {
      await phone(tester);
      await run(tester, () async {
        await tester.pumpWidget(
          const MaterialApp(home: LegalScreen(type: LegalType.terms)),
        );
        await tester.pumpAndSettle();
      });

      final prefs = await SharedPreferences.getInstance();
      final saved = jsonDecode(prefs.getString('legal_doc_terms')!);
      expect(saved['last_updated'], 'November 13, 2026');
    });
  });

  group('Delete account', () {
    test('sends the password to the server', () async {
      await http.runWithClient(() async {
        final res = await AuthService.instance.deleteAccount(
          password: 'secret123',
        );
        expect(res.ok, isTrue);
      }, () => MockClient(server.handle));

      final r = server.requests.single;
      expect(r.method, 'DELETE');
      expect(r.url.path, endsWith('/api/mobile/account'));
      expect(jsonDecode(r.body), {'password': 'secret123'});
      expect(AuthService.instance.currentUser, isNull);
    });

    test('says why when the account must be closed by Go Bike', () async {
      server.deleteStatus = 409;
      await http.runWithClient(() async {
        final res = await AuthService.instance.deleteAccount(
          password: 'secret123',
        );
        expect(res.ok, isFalse);
        expect(res.status, 409);
        expect(res.message, contains('gobike@pydn.org'));
      }, () => MockClient(server.handle));
    });

    Future<bool?> openSheet(WidgetTester tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await showDeleteAccountSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('explains what is deleted and needs the password', (
      tester,
    ) async {
      await phone(tester);
      await run(tester, () async {
        await openSheet(tester);

        expect(find.text('Delete your account?'), findsOneWidget);
        expect(find.textContaining('You cannot undo this.'), findsOneWidget);
        expect(
          find.textContaining('Check-up records about you are kept'),
          findsOneWidget,
        );

        await tester.tap(find.text('Delete my account'));
        await tester.pumpAndSettle();
        expect(find.text('Enter your password.'), findsOneWidget);
        expect(server.requests, isEmpty);
      });
    });

    testWidgets('shows the server\'s answer when the password is wrong', (
      tester,
    ) async {
      await phone(tester);
      server.deleteStatus = 422;
      await run(tester, () async {
        await openSheet(tester);
        await tester.enterText(find.byType(TextField), 'wrong-pass');
        await tester.tap(find.text('Delete my account'));
        await tester.pumpAndSettle();

        expect(find.text('The password is incorrect.'), findsOneWidget);
        expect(find.text('Delete your account?'), findsOneWidget);
      });
    });

    testWidgets('offers to email Go Bike when the account has check-ups', (
      tester,
    ) async {
      await phone(tester);
      server.deleteStatus = 409;
      await run(tester, () async {
        await openSheet(tester);
        await tester.enterText(find.byType(TextField), 'secret123');
        await tester.tap(find.text('Delete my account'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('health records must be kept'),
          findsOneWidget,
        );
        expect(find.text('Email Go Bike'), findsOneWidget);
        expect(find.text('Delete my account'), findsNothing);
      });
    });

    testWidgets('closes once the account is deleted', (tester) async {
      await phone(tester);
      await run(tester, () async {
        await openSheet(tester);
        await tester.enterText(find.byType(TextField), 'secret123');
        await tester.tap(find.text('Delete my account'));
        // Signing out clears the phone's secure storage, which only answers in real time.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 500)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Delete your account?'), findsNothing);
        expect(server.requests.single.method, 'DELETE');
      });
    });
  });
}
