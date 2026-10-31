import 'package:flutter/foundation.dart';

import 'auth_service.dart';

/// A person on the live map: a GoBiker.
class MapPerson {
  const MapPerson({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.status = 'active',
  });

  final int id;
  final String name;
  final double latitude;
  final double longitude;

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
  final DateTime? createdAt;

  bool get isOpen => status != 'resolved';
  bool get hasPosition => latitude != null && longitude != null;

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
      createdAt: DateTime.tryParse('${j['created_at'] ?? ''}')?.toLocal(),
    );
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
