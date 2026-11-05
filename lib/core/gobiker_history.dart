import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'appointments.dart';
import 'auth_service.dart';
import 'patient_service.dart';
import 'ronda_store.dart';

/// What kind of thing a History row is.
enum HistoryKind { ronda, checkup, visit, sos }

/// An emergency this GoBiker answered, as GET /gobiker/history sends it.
class SosHistory {
  const SosHistory({
    required this.id,
    required this.residentName,
    required this.barangay,
    required this.address,
    required this.landmark,
    required this.createdAt,
    this.description,
    this.cancelled = false,
    this.respondedAt,
    this.resolvedAt,
  });

  final int id;
  final String residentName;
  final String barangay;
  final String address;
  final String landmark;
  final String? description;

  /// The resident withdrew it (the server also reports such a request as resolved).
  final bool cancelled;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final DateTime? resolvedAt;

  /// When it ended: the newest date it has.
  DateTime get endedAt => resolvedAt ?? respondedAt ?? createdAt;

  String get place => [
    [address, barangay].where((s) => s.trim().isNotEmpty).join(', '),
    landmark,
  ].where((s) => s.trim().isNotEmpty).join(' · ');

  factory SosHistory.fromJson(Map<String, dynamic> j) {
    DateTime? date(dynamic v) => DateTime.tryParse('${v ?? ''}')?.toLocal();
    String? text(dynamic v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return SosHistory(
      id: (j['id'] as num?)?.toInt() ?? 0,
      residentName: text(j['resident_name']) ?? 'A resident',
      barangay: '${j['barangay'] ?? ''}',
      address: '${j['address'] ?? ''}',
      landmark: '${j['landmark'] ?? ''}',
      description: text(j['description']),
      cancelled: j['cancelled'] == true,
      createdAt: date(j['created_at']) ?? DateTime.now(),
      respondedAt: date(j['responded_at']),
      resolvedAt: date(j['resolved_at']),
    );
  }
}

/// One row of the History screen, whatever it is made from.
class HistoryEntry {
  const HistoryEntry({
    required this.kind,
    required this.time,
    required this.title,
    required this.subtitle,
    this.status,
    this.ronda,
    this.checkup,
    this.visit,
    this.sos,
  });

  final HistoryKind kind;

  /// When it happened (a ronda: when it ended).
  final DateTime time;
  final String title;
  final String subtitle;

  /// A short word for how it ended ("Done", "Declined", "Resolved"), when it has one.
  final String? status;

  // Exactly one of these is set, matching [kind].
  final Map<String, dynamic>? ronda;
  final Map<String, dynamic>? checkup;
  final Appointment? visit;
  final SosHistory? sos;
}

/// Everything this GoBiker has finished, in one list: rondas, check-ups, home visits and the
/// emergencies they answered.
///
/// Rondas are kept on the phone and the rest come from the server. Clearing hides what was
/// there at that moment on this phone only: nothing is deleted from the server, and the
/// check-ups stay in Patients.
class GobikerHistory extends ChangeNotifier {
  GobikerHistory._();
  static final GobikerHistory instance = GobikerHistory._();

  List<Map<String, dynamic>> _rondas = const [];
  List<Map<String, dynamic>> _checkups = const [];
  List<Appointment> _visits = const [];
  List<SosHistory> _sos = const [];
  DateTime? _clearedAt;

  bool loading = false;
  bool loaded = false;

  /// Set when nothing could be loaded from the server; partial results are not an error.
  String? error;

  /// Set when one part failed but the rest is shown.
  bool partial = false;

  int get _userId => AuthService.instance.currentUser?.id ?? 0;
  String get _clearedKey => 'gobiker.history.cleared.$_userId';

  DateTime? get clearedAt => _clearedAt;

  Future<void> load() async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final cleared = prefs.getString(_clearedKey);
    _clearedAt = cleared == null ? null : DateTime.tryParse(cleared);
    _rondas = await RondaStore.loadFinished(_userId);

    // Both asked at once.
    final asking = AuthService.instance.callAuthed('GET', '/gobiker/history');
    final askingPatients = PatientService.instance.list();
    final history = await asking;
    final patients = await askingPatients;

    var failed = 0;
    if (history.ok) {
      _visits = _list(history.body['appointments'])
          .map(Appointment.fromJson)
          .toList();
      _sos = _list(history.body['sos']).map(SosHistory.fromJson).toList();
    } else {
      failed++;
      error = history.message;
    }
    if (patients.ok) {
      _checkups = patients.data ?? const [];
    } else {
      failed++;
      error ??= patients.error;
    }

    // Both failed on the first try: an error, and nothing to show. Both failed on a later
    // refresh: keep what is on screen and say it is out of date. One failed: show the rest.
    final nothingCame = failed == 2;
    partial = failed == 1 || (nothingCame && loaded);
    if (!nothingCame || loaded) error = null;
    loaded = loaded || !nothingCame;
    loading = false;
    notifyListeners();
  }

  static List<Map<String, dynamic>> _list(dynamic raw) => raw is List
      ? raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
      : const [];

  /// Everything newer than the last Clear, newest first.
  List<HistoryEntry> entries() {
    final all = <HistoryEntry>[
      for (final r in _rondas)
        HistoryEntry(
          kind: HistoryKind.ronda,
          time: r['endDateTime'] as DateTime,
          title: 'Ronda · Brgy. ${r['barangay']}',
          subtitle:
              '${r['startTime']} - ${r['endTime']} · '
              '${r['patientsCount']} ${r['patientsCount'] == 1 ? 'patient' : 'patients'} · '
              '${(r['distance'] as double).toStringAsFixed(1)} km',
          status: 'Done',
          ronda: r,
        ),
      for (final c in _checkups)
        if (_recordedAt(c) != null)
          HistoryEntry(
            kind: HistoryKind.checkup,
            time: _recordedAt(c)!,
            title: 'Check-up · ${c['name']}',
            subtitle:
                'BP ${c['sys']}/${c['dia']}'
                '${'${c['barangay']}'.isEmpty ? '' : ' · Brgy. ${c['barangay']}'}',
            checkup: c,
          ),
      for (final v in _visits)
        HistoryEntry(
          kind: HistoryKind.visit,
          time: v.changedAt,
          title: 'Home visit · ${v.residentName ?? 'Resident'}',
          subtitle: '${v.address}, ${v.barangay}',
          status: switch (v.status) {
            'completed' => 'Done',
            'declined' => 'Declined by you',
            'cancelled' => 'Cancelled by the resident',
            _ => v.statusLabel,
          },
          visit: v,
        ),
      for (final s in _sos)
        HistoryEntry(
          kind: HistoryKind.sos,
          time: s.endedAt,
          title: 'SOS · ${s.residentName}',
          subtitle: s.place,
          status: s.cancelled ? 'Cancelled by the resident' : 'Resolved',
          sos: s,
        ),
    ];

    final cleared = _clearedAt;
    final shown = cleared == null
        ? all
        : all.where((e) => e.time.isAfter(cleared)).toList();
    shown.sort((a, b) => b.time.compareTo(a.time));
    return shown;
  }

  static DateTime? _recordedAt(Map<String, dynamic> c) =>
      DateTime.tryParse('${c['recorded_at'] ?? ''}');

  /// Hides everything there is now. Later things still show.
  Future<void> clear() async {
    _clearedAt = DateTime.now();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clearedKey, _clearedAt!.toIso8601String());
  }

  /// On logout: forget what is held in memory (the saved Clear stays for next time).
  void reset() {
    _rondas = const [];
    _checkups = const [];
    _visits = const [];
    _sos = const [];
    _clearedAt = null;
    loading = false;
    loaded = false;
    error = null;
    partial = false;
    notifyListeners();
  }
}
