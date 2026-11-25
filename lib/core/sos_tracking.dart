import 'package:latlong2/latlong.dart';

import 'auth_service.dart';

/// The GoBiker the admin sent to a resident's SOS, as the resident's map
/// draws them: who they are and where their phone last said they were.
class TrackedResponder {
  const TrackedResponder({
    required this.name,
    this.barangay,
    this.photoUrl,
    this.online = false,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.heading,
    this.positionAt,
  });

  final String name;
  final String? barangay;
  final String? photoUrl;

  /// Their app is on and reporting. When false, the position (if any) is the
  /// last one it sent.
  final bool online;
  final double? latitude;
  final double? longitude;

  /// How far out the position may be, in metres.
  final double? accuracy;
  final double? heading;

  /// When the position was measured.
  final DateTime? positionAt;

  bool get hasPosition => latitude != null && longitude != null;
  LatLng? get point => hasPosition ? LatLng(latitude!, longitude!) : null;

  factory TrackedResponder.fromJson(Map<String, dynamic> j) => TrackedResponder(
    name: '${j['name'] ?? 'Your GoBiker'}'.trim(),
    barangay: (j['barangay'] as String?)?.trim(),
    photoUrl: (j['photo_url'] as String?)?.trim(),
    online: j['online'] == true,
    latitude: (j['latitude'] as num?)?.toDouble(),
    longitude: (j['longitude'] as num?)?.toDouble(),
    accuracy: (j['accuracy'] as num?)?.toDouble(),
    heading: (j['heading'] as num?)?.toDouble(),
    positionAt: DateTime.tryParse('${j['position_at'] ?? ''}')?.toLocal(),
  );
}

/// One answer from GET /resident/sos/{id}/tracking.
class SosTracking {
  const SosTracking({
    required this.sosId,
    required this.status,
    this.cancelled = false,
    this.sosLatitude,
    this.sosLongitude,
    this.responder,
  });

  final int sosId;

  /// sent, responding, declined or resolved (a cancelled SOS reads resolved).
  final String status;
  final bool cancelled;
  final double? sosLatitude;
  final double? sosLongitude;

  /// Only while a GoBiker is on the way; null before one is sent and once it
  /// is over, when the server stops sharing where they are.
  final TrackedResponder? responder;

  bool get isOpen => status != 'resolved';
  LatLng? get sosPoint => sosLatitude != null && sosLongitude != null
      ? LatLng(sosLatitude!, sosLongitude!)
      : null;

  factory SosTracking.fromJson(Map<String, dynamic> j) {
    final sos = j['sos'] is Map
        ? Map<String, dynamic>.from(j['sos'] as Map)
        : const <String, dynamic>{};
    final responder = j['tracking'] == true && j['responder'] is Map
        ? TrackedResponder.fromJson(
            Map<String, dynamic>.from(j['responder'] as Map),
          )
        : null;
    return SosTracking(
      sosId: (sos['id'] as num?)?.toInt() ?? 0,
      status: '${sos['status'] ?? 'sent'}',
      cancelled: sos['cancelled'] == true,
      sosLatitude: (sos['latitude'] as num?)?.toDouble(),
      sosLongitude: (sos['longitude'] as num?)?.toDouble(),
      responder: responder,
    );
  }

  /// Where a resident's SOS is tracked.
  static String residentPath(int sosId) => '/resident/sos/$sosId/tracking';

  /// Asks the server for SOS [sosId]: at [path] when given (a GoBiker's own
  /// emergency is tracked at `/gobiker/emergency/{id}/tracking`), else at the
  /// resident's [residentPath] through [fetch].
  static Future<({SosTracking? data, String? error})> load(
    int sosId, {
    String? path,
  }) => path == null ? fetch(sosId) : _fetchFrom(path);

  /// Asks the server for a resident's SOS; tests swap this out.
  static Future<({SosTracking? data, String? error})> Function(int sosId)
  fetch = _fetch;

  static Future<({SosTracking? data, String? error})> _fetch(int sosId) =>
      _fetchFrom(residentPath(sosId));

  static Future<({SosTracking? data, String? error})> _fetchFrom(
    String path,
  ) async {
    final res = await AuthService.instance.callAuthed('GET', path);
    if (res.ok && res.body['sos'] is Map) {
      return (
        data: SosTracking.fromJson(Map<String, dynamic>.from(res.body)),
        error: null,
      );
    }
    return (
      data: null,
      error: res.ok ? 'Unexpected response from the server.' : res.message,
    );
  }
}

/// How long ago, said simply: "just now", "3 min ago", "2 h ago".
String sinceLabel(DateTime at, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(at);
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  return '${d.inHours} h ago';
}
