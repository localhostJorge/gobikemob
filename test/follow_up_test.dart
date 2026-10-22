import 'package:flutter_test/flutter_test.dart';

import 'package:go_bike_app/core/follow_up.dart';

void main() {
  group('FollowUp.from', () {
    test('reads the decision, note and date from the server', () {
      final followUp = FollowUp.from({
        'decision': 'stop',
        'note': '  All normal since July.  ',
        'decided_at': '2026-10-22T08:00:00+00:00',
      })!;

      expect(followUp.isStop, isTrue);
      expect(followUp.label, 'Stop checking');
      expect(followUp.note, 'All normal since July.');
      expect(followUp.decidedAt, isNotNull);
    });

    test('keep checking is not a stop', () {
      final followUp = FollowUp.from({'decision': 'continue', 'note': ''})!;

      expect(followUp.isStop, isFalse);
      expect(followUp.label, 'Keep checking');
      expect(followUp.note, isNull);
    });

    test('ignores a missing or unknown decision', () {
      expect(FollowUp.from(null), isNull);
      expect(FollowUp.from('stop'), isNull);
      expect(FollowUp.from({'decision': 'maybe'}), isNull);
    });

    test('survives a round trip through the patient map', () {
      final original = FollowUp.from({
        'decision': 'stop',
        'note': 'Fine.',
        'decided_at': '2026-10-22T08:00:00Z',
      })!;

      final again = FollowUp.from(original.toMap())!;

      expect(again.decision, 'stop');
      expect(again.note, 'Fine.');
      expect(again.decidedAt, original.decidedAt);
    });
  });

  group('FollowUp.forPerson', () {
    final known = <Map<String, dynamic>>[
      {
        'name': 'Lola Nena',
        'contact': '09181112222',
        'follow_up': {'decision': 'stop', 'note': null, 'decided_at': null},
      },
      {'name': 'Pedro', 'contact': '0999', 'follow_up': null},
    ];

    test('finds the person ignoring case and spaces', () {
      final found = FollowUp.forPerson(
        known,
        name: '  lola NENA ',
        contact: ' 09181112222',
      );

      expect(found?.isStop, isTrue);
    });

    test('a different contact number is a different person', () {
      expect(
        FollowUp.forPerson(known, name: 'Lola Nena', contact: '09000000000'),
        isNull,
      );
    });

    test('a known person without a decision gives nothing', () {
      expect(FollowUp.forPerson(known, name: 'Pedro', contact: '0999'), isNull);
    });

    test('an empty form matches nobody', () {
      expect(FollowUp.forPerson(known, name: '', contact: ''), isNull);
    });
  });
}
