import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'auth_service.dart';

/// A position rougher than this (metres) is drawn with a circle around it
/// showing how far out it may be.
const double roughAccuracy = 30;

/// An SOS pin rougher than this is called approximate: the address and the
/// landmark are then the better guide.
const double approximateAccuracy = 50;

double? _metres(dynamic v) {
  final m = (v as num?)?.toDouble();
  return m != null && m.isFinite && m >= 0 ? m : null;
}

/// A person on the live map: a GoBiker.
class MapPerson {
  const MapPerson({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.status = 'active',
    this.accuracy,
    this.photoUrl,
    this.barangay,
    this.onRonda = false,
  });

  final int id;
  final String name;
  final double latitude;
  final double longitude;

  /// Whether this GoBiker has started a ronda (false from servers that predate it).
  final bool onRonda;

  /// Busy with an emergency: their own, or an SOS they are responding to.
  bool get isBusy => status == 'emergency' || status == 'responding';

  /// The barangay this GoBiker covers (null from servers that predate it).
  final String? barangay;

  /// How far out the position may be, in metres (null when the server does
  /// not know).
  final double? accuracy;

  /// URL for the GoBiker's profile photo (may be null).
  final String? photoUrl;

  bool get isRough => (accuracy ?? 0) > roughAccuracy;
  LatLng get point => LatLng(latitude, longitude);

  /// GoBikers: active, emergency or responding.
  final String status;

  static MapPerson? fromJson(dynamic j) {
    if (j is! Map) return null;
    final lat = (j['latitude'] as num?)?.toDouble();
    final lng = (j['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return MapPerson(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: '${j['name'] ?? ''}',
      latitude: lat,
      longitude: lng,
      status: '${j['status'] ?? 'active'}',
      accuracy: _metres(j['accuracy']),
      photoUrl: _text(j['photo_url']),
      barangay: _text(j['barangay']),
      onRonda: j['on_ronda'] == true,
    );
  }
}

/// A trimmed string, or null when missing or blank.
String? _text(dynamic v) {
  final s = '${v ?? ''}'.trim();
  return s.isEmpty ? null : s;
}

/// A resident's SOS request the admin assigned to this GoBiker.
class AssignedSos {
  const AssignedSos({
    required this.id,
    required this.status,
    required this.residentName,
    this.address = '',
    this.barangay = '',
    required this.landmark,
    this.severity,
    this.severityLabel,
    this.injured,
    this.injuredLabel,
    this.mobile,
    this.description,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.createdAt,
    this.fromGobiker = false,
    this.assignedAt,
    this.otherResponders = const [],
  });

  final int id;

  /// responding (yellow) or resolved (green, shown for a while).
  final String status;
  final String residentName;

  /// Only from older servers: the resident no longer types an address.
  final String address;
  final String barangay;
  final String landmark;

  /// `low` to `critical`, with its label. Null when the resident was not asked
  /// (an older app, or a GoBiker's own emergency).
  final String? severity;
  final String? severityLabel;

  /// `yes`/`no`/`unsure`, with its label ("Not sure"). Null when not asked.
  final String? injured;
  final String? injuredLabel;
  final String? mobile;
  final String? description;
  final double? latitude;
  final double? longitude;

  /// How far out the pin may be, in metres (null when it was not reported).
  final double? accuracy;
  final DateTime? createdAt;

  /// The one in trouble is another GoBiker (their own emergency), not a
  /// resident.
  final bool fromGobiker;

  /// When the admin sent this GoBiker. A new time means they were sent again
  /// (say, after declining), which alerts them again. Null from older servers.
  final DateTime? assignedAt;

  /// The other GoBikers the admin sent to the same SOS.
  final List<String> otherResponders;

  bool get isOpen => status != 'resolved';
  bool get hasPosition => latitude != null && longitude != null;
  bool get isRough => hasPosition && (accuracy ?? 0) > roughAccuracy;

  /// The pin is only roughly where the resident is.
  bool get isApproximate =>
      hasPosition && (accuracy ?? 0) > approximateAccuracy;

  /// "Poblacion · Beside the chapel"; an old typed address only when neither is known.
  String get place {
    final where = [
      barangay,
      landmark,
    ].where((s) => s.trim().isNotEmpty).join(' · ');
    return where.isNotEmpty ? where : address.trim();
  }

  factory AssignedSos.fromJson(Map<String, dynamic> j) {
    String? text(dynamic v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return AssignedSos(
      id: (j['id'] as num?)?.toInt() ?? 0,
      status: '${j['status'] ?? 'responding'}',
      residentName: text(j['resident_name']) ?? 'Resident',
      address: '${j['address'] ?? ''}',
      barangay: '${j['barangay'] ?? ''}',
      landmark: '${j['landmark'] ?? ''}',
      severity: text(j['severity']),
      severityLabel: text(j['severity_label']),
      injured: text(j['injured']),
      injuredLabel: text(j['injured_label']),
      mobile: text(j['mobile']),
      description: text(j['description']),
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
      accuracy: _metres(j['accuracy']),
      createdAt: DateTime.tryParse('${j['created_at'] ?? ''}')?.toLocal(),
      fromGobiker: j['from_gobiker'] == true,
      assignedAt: DateTime.tryParse('${j['assigned_at'] ?? ''}'),
      otherResponders: switch (j['other_responders']) {
        final List<dynamic> names =>
          names.map(text).whereType<String>().toList(),
        _ => const [],
      },
    );
  }
}

/// Where each GoBiker's marker is drawn while it moves from the position the
/// map last showed to the one the server now reports, so a GoBiker is seen
/// riding along and not hopping from point to point.
///
/// [progress] runs from 0 (still at the old position) to 1 (arrived).
class MarkerGlide {
  /// A step longer than this is not a ride between two refreshes: a first
  /// position after a gap, shown at once.
  static const double maxGlideMetres = 400;

  final Map<int, LatLng> _from = {};
  final Map<int, LatLng> _to = {};

  /// Where the marker of GoBiker [id] is at [progress]; null if unknown.
  LatLng? at(int id, double progress) {
    final to = _to[id];
    final from = _from[id];
    if (to == null || from == null) return to;
    final t = progress.clamp(0.0, 1.0);
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
  }

  /// New positions arrived while the markers were at [progress] of their last
  /// move: each one now starts from where it is drawn. With [animate] off
  /// (reduced motion) every marker is placed at once.
  void retarget(
    Iterable<MapPerson> people, {
    required double progress,
    bool animate = true,
  }) {
    final drawn = {for (final id in _to.keys) id: at(id, progress)!};
    _from.clear();
    _to.clear();
    for (final p in people) {
      final shown = drawn[p.id];
      final far =
          shown != null &&
          const Distance().as(LengthUnit.Meter, shown, p.point) >
              maxGlideMetres;
      _to[p.id] = p.point;
      _from[p.id] = shown == null || far || !animate ? p.point : shown;
    }
  }
}

List<AssignedSos> _sosList(dynamic raw) => raw is List
    ? raw.whereType<Map<String, dynamic>>().map(AssignedSos.fromJson).toList()
    : const [];

/// What the live map shows: GET /gobiker/map or /resident/map.
class LiveMapData {
  const LiveMapData({
    this.barangay,
    this.town,
    this.gobikers = const [],
    this.sos = const [],
  });

  /// The viewer's barangay.
  final String? barangay;

  /// The viewer's town: every online GoBiker in it is on the map.
  final String? town;
  final List<MapPerson> gobikers;
  final List<AssignedSos> sos;

  factory LiveMapData.fromJson(Map<String, dynamic> j) {
    final raw = j['gobikers'];
    return LiveMapData(
      barangay: _text(j['barangay']),
      town: _text(j['town']),
      gobikers: raw is List
          ? raw.map(MapPerson.fromJson).whereType<MapPerson>().toList()
          : const [],
      sos: _sosList(j['sos']),
    );
  }

  static Future<({LiveMapData? data, String? error})> fetch() async {
    final gobiker = AuthService.instance.currentUser?.isGoBiker ?? false;
    final res = await AuthService.instance.callAuthed(
      'GET',
      gobiker ? '/gobiker/map' : '/resident/map',
    );
    if (!res.ok) return (data: null, error: res.message);

    return (
      data: LiveMapData.fromJson(Map<String, dynamic>.from(res.body)),
      error: null,
    );
  }
}

/// The GoBiker's open SOS requests (assigned by the admin): the dashboard
/// card and the Map badge.
class GobikerSos extends ChangeNotifier {
  GobikerSos._();
  static final GobikerSos instance = GobikerSos._();

  List<AssignedSos> open = const [];
  bool loading = false;
  bool _resolving = false;
  bool _declining = false;

  Future<void>? _loading;

  /// Reloads the list. A call made while one is running waits for that one,
  /// so whoever asks next reads the fresh list and not the old one.
  Future<void> load() => _loading ??= _load().whenComplete(() {
    _loading = null;
  });

  Future<void> _load() async {
    loading = true;
    try {
      final res = await AuthService.instance.callAuthed('GET', '/gobiker/sos');
      if (res.ok) open = _sosList(res.body['sos']);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Marks the SOS as resolved. Returns null or an error message.
  Future<String?> resolve(int id) async {
    if (_resolving) return null;
    _resolving = true;
    try {
      final res = await AuthService.instance.callAuthed(
        'POST',
        '/gobiker/sos/$id/resolve',
      );
      await load();
      return res.ok ? null : res.message;
    } finally {
      _resolving = false;
    }
  }

  /// Turns the SOS down with the required reason. The admin is alerted to
  /// send someone else, and the request leaves this GoBiker's list. Returns
  /// null or an error message.
  Future<String?> decline(int id, String reason) async {
    if (_declining) return null;
    _declining = true;
    try {
      final res = await AuthService.instance.callAuthed(
        'POST',
        '/gobiker/sos/$id/decline',
        body: {'reason': reason},
      );
      await load();
      return res.ok ? null : res.message;
    } finally {
      _declining = false;
    }
  }

  void reset() {
    open = const [];
    notifyListeners();
  }
}
