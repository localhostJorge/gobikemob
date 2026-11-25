import 'package:flutter/foundation.dart';

import 'auth_service.dart';

/// One message in the GoBiker's thread with the admin: either one the GoBiker
/// sent (with the admin's reply, if any), or one the admin started
/// ([fromAdmin]).
class GobikerMessage {
  const GobikerMessage({
    required this.id,
    required this.message,
    required this.sentAt,
    this.reply,
    this.repliedAt,
    this.repliedBy,
    this.fromAdmin = false,
  });

  final int id;

  /// What the GoBiker wrote, or the admin's text when [fromAdmin].
  final String message;
  final DateTime sentAt;

  /// The admin's answer, null until they reply.
  final String? reply;
  final DateTime? repliedAt;
  final String? repliedBy;

  /// The admin started this message: [message] is theirs, and there is no
  /// GoBiker text to show.
  final bool fromAdmin;

  bool get hasReply => reply != null && reply!.trim().isNotEmpty;

  /// Something from the admin the GoBiker should see: a reply, or a message
  /// the admin started.
  bool get hasAdminText => fromAdmin || hasReply;

  static GobikerMessage? from(dynamic raw) {
    if (raw is! Map) return null;
    final id = int.tryParse('${raw['id']}');
    final fromAdmin =
        raw['from_admin'] == true || '${raw['from_admin']}' == '1';
    final reply = '${raw['reply'] ?? ''}'.trim();
    var text = '${raw['message'] ?? ''}'.trim();
    // An admin-started row carries its text in `message`; take `reply` if a
    // server ever puts it there instead.
    if (fromAdmin && text.isEmpty) text = reply;
    if (id == null || text.isEmpty) return null;
    return GobikerMessage(
      id: id,
      message: text,
      fromAdmin: fromAdmin,
      sentAt:
          DateTime.tryParse('${raw['sent_at'] ?? ''}')?.toLocal() ??
          DateTime.now(),
      reply: fromAdmin || reply.isEmpty ? null : reply,
      repliedAt: DateTime.tryParse('${raw['replied_at'] ?? ''}')?.toLocal(),
      repliedBy: () {
        final s = '${raw['replied_by'] ?? ''}'.trim();
        return s.isEmpty ? null : s;
      }(),
    );
  }
}

/// The GoBiker's conversation with the admin (`GET /gobiker/messages`,
/// send with `POST /gobiker/message`).
///
/// Newest first from the server; [conversation] returns it oldest first for
/// a chat view. Kept in memory only — the server holds the history.
class GobikerMessages extends ChangeNotifier {
  GobikerMessages._();
  static final GobikerMessages instance = GobikerMessages._();

  List<GobikerMessage> _items = [];
  bool _loading = false;
  bool _loaded = false;
  bool _sending = false;

  /// Messages with a reply already shown to the GoBiker. In memory only, so a
  /// fresh app start counts recent replies as new again — that is fine for a
  /// "you have a reply" badge.
  final Set<int> _seenReplyIds = {};

  /// Messages newest first, as the server sends them.
  List<GobikerMessage> get items => List.unmodifiable(_items);

  /// Oldest first, for a chat thread that reads top to bottom.
  List<GobikerMessage> get conversation => List.unmodifiable(_items.reversed);

  bool get loading => _loading;
  bool get sending => _sending;
  bool get loaded => _loaded;

  /// True once the admin has written anything: a reply, or a message they
  /// started (drives the dashboard badge).
  bool get hasReplies => _items.any((m) => m.hasAdminText);

  /// How many of the GoBiker's own messages have no answer yet.
  int get unansweredCount =>
      _items.where((m) => !m.fromAdmin && !m.hasReply).length;

  /// How many admin replies and admin-started messages the GoBiker has not
  /// seen yet. They all count until [markRepliesSeen] runs (opening the
  /// thread).
  int get unseenReplyCount => _items
      .where((m) => m.hasAdminText && !_seenReplyIds.contains(m.id))
      .length;

  /// Marks every admin text on screen as seen (called when the thread opens).
  void markRepliesSeen() {
    if (unseenReplyCount == 0) return;
    _seenReplyIds.addAll(_items.where((m) => m.hasAdminText).map((m) => m.id));
    notifyListeners();
  }

  /// Clears the list (signing out).
  void reset() {
    _items = [];
    _seenReplyIds.clear();
    _loaded = false;
    _sending = false;
    notifyListeners();
  }

  /// Downloads the conversation. A failed refresh keeps what is on screen.
  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      final res = await AuthService.instance.callAuthed(
        'GET',
        '/gobiker/messages',
      );
      if (res.ok) {
        final raw = res.body['messages'];
        _items = raw is List
            ? raw.map(GobikerMessage.from).whereType<GobikerMessage>().toList()
            : [];
        _loaded = true;
        notifyListeners();
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Sends a message to the admin and reloads. Returns null on success or an
  /// error message.
  Future<String?> send(String text) async {
    final body = text.trim();
    if (body.isEmpty) return 'Please type a message first.';
    if (_sending) return null;
    _sending = true;
    notifyListeners();
    try {
      final res = await AuthService.instance.callAuthed(
        'POST',
        '/gobiker/message',
        body: {'message': body},
      );
      if (res.ok) {
        await refresh();
        return null;
      }
      return res.message;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }
}
