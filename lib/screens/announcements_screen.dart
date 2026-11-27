import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/announcements.dart';
import '../core/link_text.dart';
import '../core/theme.dart';
import 'patient/app_colors.dart';

/// Every live announcement from the admin, newest first.
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  // Which ones were new when the screen opened, so they keep their "New" tag while reading.
  late final Set<int> _newOnOpen;

  @override
  void initState() {
    super.initState();
    _newOnOpen = {
      for (final a in Announcements.instance.items)
        if (Announcements.instance.isNew(a)) a.id,
    };
    Announcements.instance.markAllSeen();
    Announcements.instance.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text('Announcements'),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Announcements.instance,
          builder: (context, _) {
            final items = Announcements.instance.items;
            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.campaign_outlined, size: 56, color: muted),
                      const SizedBox(height: 16),
                      const Text(
                        'No announcements',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Messages from the admin will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: muted),
                      ),
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: Announcements.instance.refresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) => ExpandableAnnouncementCard(
                  announcement: items[index],
                  isNew: _newOnOpen.contains(items[index].id),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Announcement card that opens on tap to show the whole message, with tappable links.
class ExpandableAnnouncementCard extends StatefulWidget {
  const ExpandableAnnouncementCard({
    super.key,
    required this.announcement,
    this.isNew = false,
  });

  final Announcement announcement;
  final bool isNew;

  @override
  State<ExpandableAnnouncementCard> createState() =>
      _ExpandableAnnouncementCardState();
}

class _ExpandableAnnouncementCardState
    extends State<ExpandableAnnouncementCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // Every card opens: admin posts only have a message, and its links work once opened.
    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(16),
      child: AnnouncementCard(
        announcement: widget.announcement,
        isNew: widget.isNew,
        maxLines: _expanded ? null : 3,
        showExpandIcon: true,
      ),
    );
  }
}

/// The opened message: links open in the browser, and a long press selects text to copy.
class _LinkedMessage extends StatefulWidget {
  const _LinkedMessage({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<_LinkedMessage> createState() => _LinkedMessageState();
}

class _LinkedMessageState extends State<_LinkedMessage> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  Future<void> _open(Uri uri) async {
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);
    if (!opened && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text("Couldn't open that link.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final linkStyle = TextStyle(
      color: context.pal.brand,
      decoration: TextDecoration.underline,
      decorationColor: context.pal.brand,
    );

    return SelectableText.rich(
      TextSpan(
        style: widget.style,
        children: [
          for (final part in splitLinks(widget.text))
            if (part.link == null)
              TextSpan(text: part.text)
            else
              TextSpan(
                text: part.text,
                style: linkStyle,
                recognizer: _tapToOpen(part.link!),
              ),
        ],
      ),
    );
  }

  TapGestureRecognizer _tapToOpen(Uri uri) {
    final r = TapGestureRecognizer()..onTap = () => _open(uri);
    _recognizers.add(r);
    return r;
  }
}

/// One announcement: title, message, and when it was posted.
class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({
    super.key,
    required this.announcement,
    this.isNew = false,
    this.maxLines,
    this.showExpandIcon = false,
  });

  final Announcement announcement;
  final bool isNew;
  final int? maxLines;
  final bool showExpandIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final posted = announcement.postedAt == null
        ? null
        : DateFormat('MMM d, yyyy · h:mm a').format(announcement.postedAt!);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNew
              ? AppTheme.orange.withValues(alpha: 0.6)
              : theme.dividerColor,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.campaign_rounded, color: context.pal.orangeText),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        announcement.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (isNew) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.blue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'New',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                if (maxLines == null)
                  _LinkedMessage(
                    text: (announcement.content?.isNotEmpty ?? false)
                        ? announcement.content!
                        : announcement.body,
                    style: TextStyle(fontSize: 13, height: 1.4, color: muted),
                  )
                else
                  Text(
                    announcement.body,
                    maxLines: maxLines,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, height: 1.4, color: muted),
                  ),
                if (showExpandIcon)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      maxLines == null
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 20,
                      color: muted,
                    ),
                  ),
                if (posted != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Posted $posted',
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
