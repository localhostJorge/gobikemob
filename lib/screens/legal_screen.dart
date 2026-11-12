import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_config.dart';
import '../core/theme.dart';
import '../widgets/auth_widgets.dart';

enum LegalType { terms, privacy }

extension on LegalType {
  /// The document's key in the API (`/legal/{key}`).
  String get key => this == LegalType.terms ? 'terms' : 'privacy';

  String get fallbackTitle =>
      this == LegalType.terms ? 'Terms & Conditions' : 'Privacy Policy';

  /// The page on the website, used when the text can't be loaded.
  String get websitePath =>
      this == LegalType.terms ? '/terms' : '/privacy-policy';

  String get intro => this == LegalType.terms
      ? 'These terms apply when you use the RondaGo app, the Go Bike Project website and our programs. By creating an account you agree to them.'
      : 'How the Go Bike Project collects, uses, shares and protects your personal information when you use RondaGo, and your rights under the Data Privacy Act of 2012.';
}

/// The website address (the API without its "/api" ending), for relative links.
final String _siteBase = kApiBaseUrl.replaceFirst(RegExp(r'/api/?$'), '');

/// The Terms & Conditions or Privacy Policy, loaded from the website, where admins publish them
/// (Admin → Legal), so the app always shows the version in force. The last copy that loaded is
/// kept on the phone and shown when there is no connection.
class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key, required this.type});

  final LegalType type;

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  _LegalDocument? _doc;
  bool _loading = true;
  bool _offline =
      false; // showing the saved copy because the latest couldn't load

  String get _cacheKey => 'legal_doc_${widget.type.key}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _offline = false;
    });

    // The saved copy first, so the text shows at once even on a slow connection.
    final prefs = await SharedPreferences.getInstance();
    final saved = _LegalDocument.tryParse(prefs.getString(_cacheKey));
    if (saved != null && mounted && _doc == null) setState(() => _doc = saved);

    try {
      final res = await http
          .get(
            Uri.parse('$kApiBaseUrl/legal/${widget.type.key}'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));
      final latest = res.statusCode == 200
          ? _LegalDocument.tryParse(res.body)
          : null;
      if (latest == null) throw const FormatException('Unexpected response');

      await prefs.setString(_cacheKey, res.body);
      if (!mounted) return;
      setState(() {
        _doc = latest;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _offline = _doc != null;
      });
    }
  }

  String get _websiteUrl => _doc?.url ?? '$_siteBase${widget.type.websitePath}';

  /// Opens a link from the text. The Terms and the Privacy Policy open here in the app.
  Future<void> _openLink(String link) async {
    if (link == '/terms' || link == '/privacy-policy') {
      final type = link == '/terms' ? LegalType.terms : LegalType.privacy;
      if (type == widget.type) return;
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => LegalScreen(type: type)));
      return;
    }

    final uri = Uri.parse(link.startsWith('/') ? '$_siteBase$link' : link);
    final opened = await launchUrl(
      uri,
      mode: uri.scheme == 'mailto'
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    ).catchError((_) => false);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Couldn't open $uri")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final doc = _doc;

    return Scaffold(
      backgroundColor: authBackground(context),
      appBar: AppBar(
        backgroundColor: authBackground(context),
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          doc?.title ?? widget.type.fallbackTitle,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: doc == null
            ? (_loading
                  ? const Center(child: CircularProgressIndicator())
                  : _LoadError(
                      onRetry: _load,
                      onOpenWebsite: () => _openLink(_websiteUrl),
                    ))
            : RefreshIndicator(
                onRefresh: _load,
                child: _DocumentView(
                  doc: doc,
                  intro: widget.type.intro,
                  offline: _offline,
                  onLink: _openLink,
                  onOpenWebsite: () => _openLink(_websiteUrl),
                ),
              ),
      ),
    );
  }
}

class _DocumentView extends StatelessWidget {
  const _DocumentView({
    required this.doc,
    required this.intro,
    required this.offline,
    required this.onLink,
    required this.onOpenWebsite,
  });

  final _LegalDocument doc;
  final String intro;
  final bool offline;
  final void Function(String link) onLink;
  final VoidCallback onOpenWebsite;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.6);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        if (doc.lastUpdated.isNotEmpty)
          Text(
            'Last updated: ${doc.lastUpdated}',
            style: TextStyle(fontSize: 12, color: muted),
          ),
        if (offline) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.cloud_off_rounded, size: 16, color: muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You are offline. This is the copy saved on your phone.',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Text(
          intro,
          style: TextStyle(fontSize: 14, height: 1.5, color: onSurface),
        ),
        const SizedBox(height: 24),
        for (final section in doc.sections) ...[
          if (section.title.isNotEmpty) ...[
            Text(
              section.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 8),
          ],
          _LegalText(section.content, onLink: onLink),
          const SizedBox(height: 24),
        ],
        Center(
          child: TextButton.icon(
            onPressed: onOpenWebsite,
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Open on the website'),
          ),
        ),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry, required this.onOpenWebsite});

  final VoidCallback onRetry;
  final VoidCallback onOpenWebsite;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface
        .withValues(alpha: 0.6);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: muted),
            const SizedBox(height: 12),
            const Text(
              "Couldn't load this page",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: muted),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: AppTheme.blue),
              child: const Text('Try again'),
            ),
            TextButton(
              onPressed: onOpenWebsite,
              child: const Text('Open on the website'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- the document

class _LegalSection {
  const _LegalSection(this.title, this.content);
  final String title;
  final String content;
}

class _LegalDocument {
  const _LegalDocument({
    required this.title,
    required this.lastUpdated,
    required this.url,
    required this.sections,
  });

  final String title;
  final String lastUpdated;
  final String? url;
  final List<_LegalSection> sections;

  /// The API's JSON, or null when it isn't a usable document.
  static _LegalDocument? tryParse(String? body) {
    if (body == null || body.isEmpty) return null;
    try {
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) return null;
      final sections = (json['sections'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (s) => _LegalSection(
              (s['title'] ?? '').toString().trim(),
              (s['content'] ?? '').toString().trim(),
            ),
          )
          .where((s) => s.title.isNotEmpty || s.content.isNotEmpty)
          .toList();
      if (sections.isEmpty) return null;

      return _LegalDocument(
        title: (json['title'] ?? '').toString(),
        lastUpdated: (json['last_updated'] ?? '').toString(),
        url: json['url']?.toString(),
        sections: sections,
      );
    } catch (_) {
      return null;
    }
  }
}

// ---------------------------------------------------------------- the text format

/// A run of text in a paragraph or list item: plain, bold, or a link.
class _Run {
  _Run(this.text, {this.bold = false, this.link});
  final String text;
  final bool bold;
  final String? link;
  TapGestureRecognizer? tap;
}

/// A paragraph ([marker] null) or a list item ("•", or "1." for numbered lists).
class _Block {
  _Block(this.runs, {this.marker, this.gapBefore = false});
  final List<_Run> runs;
  final String? marker;
  final bool gapBefore;
}

/// Shows text in the format the website's legal editor uses: a blank line starts a paragraph,
/// lines starting with "- " or "1. " are list items, **bold**, [text](link), and bare web and
/// email addresses become links.
class _LegalText extends StatefulWidget {
  const _LegalText(this.content, {required this.onLink});

  final String content;
  final void Function(String link) onLink;

  @override
  State<_LegalText> createState() => _LegalTextState();
}

class _LegalTextState extends State<_LegalText> {
  static final _listLine = RegExp(r'^(?:([-•])|(\d+)[.)])\s+(.+)$');
  static final _inline = RegExp(
    r'\*\*(.+?)\*\*'
    r'|\[([^\]]+)\]\(((?:https?://|/|mailto:)[^\s)]+)\)'
    r'|(https?://[^\s<]*[^\s<.,;:!?)])'
    r'|([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})',
  );

  List<_Block> _blocks = const [];

  @override
  void initState() {
    super.initState();
    _blocks = _parse(widget.content);
  }

  @override
  void didUpdateWidget(_LegalText old) {
    super.didUpdateWidget(old);
    if (old.content != widget.content) {
      _disposeTaps();
      _blocks = _parse(widget.content);
    }
  }

  @override
  void dispose() {
    _disposeTaps();
    super.dispose();
  }

  void _disposeTaps() {
    for (final block in _blocks) {
      for (final run in block.runs) {
        run.tap?.dispose();
      }
    }
  }

  List<_Block> _parse(String content) {
    final blocks = <_Block>[];
    for (final chunk in content.trim().split(RegExp(r'\n\s*\n'))) {
      var first = true;
      final paragraph = <String>[];

      void flushParagraph() {
        if (paragraph.isEmpty) return;
        blocks.add(
          _Block(
            _runs(paragraph.join('\n')),
            gapBefore: first && blocks.isNotEmpty,
          ),
        );
        paragraph.clear();
        first = false;
      }

      for (final raw in chunk.split('\n')) {
        final line = raw.trim();
        if (line.isEmpty) continue;
        final item = _listLine.firstMatch(line);
        if (item == null) {
          paragraph.add(line);
          continue;
        }
        flushParagraph();
        blocks.add(
          _Block(
            _runs(item.group(3)!),
            marker: item.group(1) != null ? '•' : '${item.group(2)}.',
            gapBefore: first && blocks.isNotEmpty,
          ),
        );
        first = false;
      }
      flushParagraph();
    }
    return blocks;
  }

  List<_Run> _runs(String text, {bool bold = false}) {
    final runs = <_Run>[];
    var at = 0;
    for (final m in _inline.allMatches(text)) {
      if (m.start > at) runs.add(_Run(text.substring(at, m.start), bold: bold));
      if (m.group(1) != null) {
        runs.addAll(_runs(m.group(1)!, bold: true));
      } else if (m.group(2) != null) {
        runs.add(_link(m.group(2)!, m.group(3)!, bold));
      } else if (m.group(4) != null) {
        runs.add(_link(m.group(4)!, m.group(4)!, bold));
      } else {
        runs.add(_link(m.group(5)!, 'mailto:${m.group(5)}', bold));
      }
      at = m.end;
    }
    if (at < text.length) runs.add(_Run(text.substring(at), bold: bold));
    return runs;
  }

  _Run _link(String text, String link, bool bold) {
    return _Run(text, bold: bold, link: link)
      ..tap = (TapGestureRecognizer()..onTap = () => widget.onLink(link));
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final base = TextStyle(
      fontSize: 14,
      height: 1.55,
      color: onSurface.withValues(alpha: 0.72),
    );
    final linkColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF8AB4FF)
        : AppTheme.blue;

    TextSpan span(_Block block) => TextSpan(
      style: base,
      children: [
        for (final run in block.runs)
          TextSpan(
            text: run.text,
            recognizer: run.tap,
            style: TextStyle(
              fontWeight: run.bold ? FontWeight.w700 : null,
              color: run.link != null
                  ? linkColor
                  : (run.bold ? onSurface : null),
              decoration: run.link != null ? TextDecoration.underline : null,
              decorationColor: linkColor,
            ),
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in _blocks)
          Padding(
            padding: EdgeInsets.only(
              top: block.gapBefore ? 10 : 0,
              bottom: block.marker != null ? 4 : 0,
            ),
            child: block.marker == null
                ? Text.rich(span(block))
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                        child: Text(block.marker!, style: base),
                      ),
                      Expanded(child: Text.rich(span(block))),
                    ],
                  ),
          ),
      ],
    );
  }
}
