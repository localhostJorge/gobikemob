/// Splits text into plain parts and web links, so links can be made tappable.
///
/// Finds `http://`, `https://` and `www.` links. Punctuation that ends a sentence
/// (`. , ; : ! ? )`) stays outside the link, and a `www.` link opens as `https://`.
List<({String text, Uri? link})> splitLinks(String text) {
  final parts = <({String text, Uri? link})>[];
  var plainStart = 0;

  for (final m in _linkPattern.allMatches(text)) {
    var raw = m.group(0)!;
    while (raw.isNotEmpty && _trailing.contains(raw[raw.length - 1])) {
      raw = raw.substring(0, raw.length - 1);
    }
    final uri = Uri.tryParse(
      raw.toLowerCase().startsWith('www.') ? 'https://$raw' : raw,
    );
    if (raw.isEmpty || uri == null || uri.host.isEmpty) continue;

    if (m.start > plainStart) {
      parts.add((text: text.substring(plainStart, m.start), link: null));
    }
    parts.add((text: raw, link: uri));
    plainStart = m.start + raw.length;
  }

  if (plainStart < text.length || parts.isEmpty) {
    parts.add((text: text.substring(plainStart), link: null));
  }
  return parts;
}

final _linkPattern = RegExp(r'(?:https?://|www\.)\S+', caseSensitive: false);
const _trailing = '.,;:!?)';
