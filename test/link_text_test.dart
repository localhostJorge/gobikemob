import 'package:flutter_test/flutter_test.dart';

import 'package:go_bike_app/core/link_text.dart';

void main() {
  test('finds a link and leaves the full stop after it as text', () {
    final parts = splitLinks('See https://gobike.app/x. Thanks');

    expect(parts.map((p) => p.text), [
      'See ',
      'https://gobike.app/x',
      '. Thanks',
    ]);
    expect(parts[0].link, isNull);
    expect(parts[1].link.toString(), 'https://gobike.app/x');
    expect(parts[2].link, isNull);
  });

  test('opens a www link over https', () {
    final parts = splitLinks('Form: www.example.com/sign-up');

    expect(parts.last.text, 'www.example.com/sign-up');
    expect(parts.last.link.toString(), 'https://www.example.com/sign-up');
  });

  test('keeps a closing bracket out of the link', () {
    final parts = splitLinks('(details at http://a.b/c)');

    expect(parts.map((p) => p.text), ['(details at ', 'http://a.b/c', ')']);
  });

  test('finds several links', () {
    final links = splitLinks('One https://a.ph and two http://b.ph/x?y=1, done')
        .where((p) => p.link != null)
        .map((p) => p.link.toString());

    expect(links, ['https://a.ph', 'http://b.ph/x?y=1']);
  });

  test('text with no link is one plain part', () {
    final parts = splitLinks('Ronda starts at 7:30 AM.');

    expect(parts, hasLength(1));
    expect(parts.single.text, 'Ronda starts at 7:30 AM.');
    expect(parts.single.link, isNull);
  });
}
