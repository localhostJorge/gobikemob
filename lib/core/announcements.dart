import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

/// One announcement the admin posted for all GoBikers.
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    this.postedAt,
    this.expiresAt,
  });

  final int id;
  final String title;
  final String body;
  final DateTime? postedAt;
  final DateTime? expiresAt;

  static Announcement? from(dynamic raw) {
    if (raw is! Map) return null;
    final id = int.tryParse('${raw['id']}');
    final title = '${raw['title'] ?? ''}'.trim();
    if (id == null || title.isEmpty) return null;
    return Announcement(
      id: id,
      title: title,
      body: '${raw['body'] ?? ''}'.trim(),
      postedAt: DateTime.tryParse('${raw['posted_at'] ?? ''}')?.toLocal(),
      expiresAt: DateTime.tryParse('${raw['expires_at'] ?? ''}')?.toLocal(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'body': body,
    'posted_at': postedAt?.toUtc().toIso8601String(),
    'expires_at': expiresAt?.toUtc().toIso8601String(),
  };

  /// No longer shown once the admin's end date has passed.
  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());
}

/// The admin's announcements (`GET /gobiker/announcements`).
///
/// The last list is kept on the phone, so announcements still show without a
/// connection. Which ones the GoBiker has seen is remembered too.
class Announcements extends ChangeNotifier {
  Announcements._();
  static final Announcements instance = Announcements._();

  static const _cacheKey = 'announcements_cache';
  static const _seenKey = 'announcements_seen';

  List<Announcement> _items = [];
  Set<int> _seen = {};
  bool _loaded = false;
  bool _refreshing = false;

  /// Live announcements, newest first.
  List<Announcement> get items =>
      List.unmodifiable(_items.where((a) => !a.isExpired));

  Announcement? get latest => items.isEmpty ? null : items.first;

  /// How many announcements the GoBiker has not opened yet.
  int get unseenCount => items.where(isNew).length;

  bool isNew(Announcement announcement) => !_seen.contains(announcement.id);

  /// Reads the saved list and what was seen. Safe to call more than once.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        _items = _parse(jsonDecode(cached));
      }
      _seen = (prefs.getStringList(_seenKey) ?? [])
          .map(int.tryParse)
          .whereType<int>()
          .toSet();
    } catch (e) {
      debugPrint('announcements: could not read saved state: $e');
    }
    notifyListeners();
  }

  /// Downloads the announcements. A failed refresh keeps what is on the phone.
  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await load();
      final res = await AuthService.instance.callAuthed(
        'GET',
        '/gobiker/announcements',
      );
      if (!res.ok) return;
      _items = _parse(res.body['announcements']);
      _seen.removeWhere((id) => !_items.any((a) => a.id == id));
      notifyListeners();
      await _save();
    } finally {
      _refreshing = false;
    }
  }

  /// The GoBiker opened the announcements: nothing is new any more.
  Future<void> markAllSeen() async {
    final ids = _items.map((a) => a.id).toSet();
    if (ids.difference(_seen).isEmpty) return;
    _seen = {..._seen, ...ids};
    notifyListeners();
    await _save();
  }

  /// Forget everything (signing out, and tests).
  Future<void> reset() async {
    _items = [];
    _seen = {};
    _loaded = false;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_seenKey);
    } catch (_) {}
  }

  /// Replaces the list (used by tests).
  @visibleForTesting
  void setItems(List<Announcement> items) {
    _items = items;
    _loaded = true;
    notifyListeners();
  }

  static List<Announcement> _parse(dynamic raw) {
    if (raw is! List) return [];
    return raw.map(Announcement.from).whereType<Announcement>().toList();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        jsonEncode(_items.map((a) => a.toMap()).toList()),
      );
      await prefs.setStringList(_seenKey, _seen.map((id) => '$id').toList());
    } catch (e) {
      debugPrint('announcements: could not save state: $e');
    }
  }
}
