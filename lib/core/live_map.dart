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
  });

  final int id;
  final String name;
  final double latitude;
  final double longitude;

  /// How far out the position may be, in metres (null when the server does
  /// not know).
  final double? accuracy;

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
    );
  }
}

/// A resident's SOS request the admin assigned to this GoBiker.
class AssignedSos {
  const AssignedSos({
    required this.id,
    required this.status,
    required this.residentName,
    required this.address,
    required this.landmark,
    this.mobile,
    this.description,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.createdAt,
  });

  final int id;

  /// responding (yellow) or resolved (green, shown for a while).
  final String status;
  final String residentName;
  final String address;
  final String landmark;
  final String? mobile;
  final String? description;
  final double? latitude;
  final double? longitude;

  /// How far out the pin may be, in metres (null when it was not reported).
  final double? accuracy;
  final DateTime? createdAt;

  bool get isOpen => status != 'resolved';
  bool get hasPosition => latitude != null && longitude != null;
  bool get isRough => hasPosition && (accuracy ?? 0) > roughAccuracy;

  /// The pin is only roughly where the resident is.
  bool get isApproximate =>
      hasPosition && (accuracy ?? 0) > approximateAccuracy;

  String get place =>
      [address, landmark].where((s) => s.trim().isNotEmpty).join(' · ');

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
      landmark: '${j['landmark'] ?? ''}',
      mobile: text(j['mobile']),
      description: text(j['description']),
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
      accuracy: _metres(j['accuracy']),
      createdAt: DateTime.tryParse('${j['created_at'] ?? ''}')?.toLocal(),
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
    this.gobikers = const [],
    this.sos = const [],
  });

  final String? barangay;
  final List<MapPerson> gobikers;
  final List<AssignedSos> sos;

  static Future<({LiveMapData? data, String? error})> fetch() async {
    final gobiker = AuthService.instance.currentUser?.isGoBiker ?? false;
    final res = await AuthService.instance.callAuthed(
      'GET',
      gobiker ? '/gobiker/map' : '/resident/map',
    );
    if (!res.ok) return (data: null, error: res.message);

    List<MapPerson> people(dynamic raw) => raw is List
        ? raw.map(MapPerson.fromJson).whereType<MapPerson>().toList()
        : const [];
    return (
      data: LiveMapData(
        barangay: res.body['barangay']?.toString(),
        gobikers: people(res.body['gobikers']),
        sos: _sosList(res.body['sos']),
      ),
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

  Future<void> load() async {
    if (loading) return;
    loading = true;
    final res = await AuthService.instance.callAuthed('GET', '/gobiker/sos');
    if (res.ok) open = _sosList(res.body['sos']);
    loading = false;
    notifyListeners();
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

  void reset() {
    open = const [];
    notifyListeners();
  }
}
