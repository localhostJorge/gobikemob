import 'package:flutter/foundation.dart';

import 'auth_service.dart';

/// One message this GoBiker sent the admin, with the admin's reply if any.
class GobikerMessage {
  const GobikerMessage({
    required this.id,
    required this.message,
    required this.sentAt,
    this.reply,
    this.repliedAt,
    this.repliedBy,
  });

  final int id;

  /// What the GoBiker wrote.
  final String message;
  final DateTime sentAt;

  /// The admin's answer, null until they reply.
  final String? reply;
  final DateTime? repliedAt;
  final String? repliedBy;

  bool get hasReply => reply != null && reply!.trim().isNotEmpty;

  static GobikerMessage? from(dynamic raw) {
    if (raw is! Map) return null;
    final id = int.tryParse('${raw['id']}');
    final text = '${raw['message'] ?? ''}'.trim();
    if (id == null || text.isEmpty) return null;
    return GobikerMessage(
      id: id,
      message: text,
      sentAt:
          DateTime.tryParse('${raw['sent_at'] ?? ''}')?.toLocal() ??
          DateTime.now(),
      reply: () {
        final s = '${raw['reply'] ?? ''}'.trim();
        return s.isEmpty ? null : s;
      }(),
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

  /// True once any message has an admin reply (drives the dashboard badge).
  bool get hasReplies => _items.any((m) => m.hasReply);

  /// How many messages came back without an answer yet.
  int get unansweredCount => _items.where((m) => !m.hasReply).length;

  /// How many admin replies the GoBiker has not seen yet. Everything with a
  /// reply counts until [markRepliesSeen] runs (opening the thread).
  int get unseenReplyCount =>
      _items.where((m) => m.hasReply && !_seenReplyIds.contains(m.id)).length;

  /// Marks every reply on screen as seen (called when the thread opens).
  void markRepliesSeen() {
    if (unseenReplyCount == 0) return;
    _seenReplyIds.addAll(_items.where((m) => m.hasReply).map((m) => m.id));
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
