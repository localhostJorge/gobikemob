import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_bike_app/core/gobiker_messages.dart';
import 'package:go_bike_app/screens/gobiker_messages_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _sent = DateTime.utc(2026, 11, 26, 2).toIso8601String();

/// `GET /gobiker/messages`: newest first, one the admin started and one the
/// GoBiker wrote (still unanswered).
final _api = MockClient((req) async {
  if (!req.url.path.endsWith('/gobiker/messages')) {
    return http.Response('not found', 404);
  }
  return http.Response(
    jsonEncode({
      'messages': [
        {
          'id': 9,
          'message': 'Please check in at the health center.',
          'from_admin': true,
          'reply': null,
          'sent_at': _sent,
          'replied_at': _sent,
          'replied_by': 'Admin Reyes',
        },
        {'id': 8, 'message': 'Flat tire', 'reply': null, 'sent_at': _sent},
      ],
    }),
    200,
  );
});

void main() {
  tearDown(GobikerMessages.instance.reset);

  test('a from_admin row is kept, with the admin text as its message', () {
    final m = GobikerMessage.from({
      'id': 9,
      'message': 'Please check in.',
      'from_admin': true,
      'reply': '',
      'sent_at': _sent,
    });
    expect(m, isNotNull);
    expect(m!.fromAdmin, isTrue);
    expect(m.message, 'Please check in.');

    final old = GobikerMessage.from({
      'id': 1,
      'message': 'Hi',
      'sent_at': _sent,
    });
    expect(old!.fromAdmin, isFalse);
  });

  test('a message the admin started counts as an unseen reply', () async {
    await http.runWithClient(() async {
      await GobikerMessages.instance.refresh();
      final store = GobikerMessages.instance;
      expect(store.items, hasLength(2));
      expect(store.unseenReplyCount, 1);
      expect(store.hasReplies, isTrue);
      // Only the GoBiker's own message is waiting for an answer.
      expect(store.unansweredCount, 1);
      store.markRepliesSeen();
      expect(store.unseenReplyCount, 0);
    }, () => _api);
  });

  testWidgets('a message the admin started shows on the left, "From admin"', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: GobikerMessagesScreen()));
      await tester.pumpAndSettle();

      expect(find.text('From admin'), findsOneWidget);
      final width = tester.getSize(find.byType(Scaffold)).width;
      final admin = find.text('Please check in at the health center.');
      expect(admin, findsOneWidget);
      expect(tester.getTopLeft(admin).dx, lessThan(width / 4));
      // The GoBiker's own message stays on the right.
      expect(
        tester.getTopRight(find.text('Flat tire')).dx,
        greaterThan(width * 3 / 4),
      );
    }, () => _api);
  });
}
