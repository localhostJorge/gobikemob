import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'auth_service.dart';

/// One SOS request the resident sent, as GET /api/resident/sos returns it.
class SosEntry {
  const SosEntry({
    required this.id,
    required this.status,
    required this.statusLabel,
    required this.municipality,
    required this.barangay,
    required this.landmark,
    required this.createdAt,
    this.description,
    this.hasPhoto = false,
    this.hasVideo = false,
    this.respondedAt,
    this.resolvedAt,
  });

  final int id;

  /// `sent`, `responding` or `resolved`.
  final String status;
  final String statusLabel;
  final String municipality;
  final String barangay;
  final String landmark;
  final String? description;
  final bool hasPhoto;
  final bool hasVideo;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final DateTime? resolvedAt;

  bool get isOpen => status != 'resolved';

  factory SosEntry.fromJson(Map<String, dynamic> j) {
    DateTime? date(dynamic v) => DateTime.tryParse('${v ?? ''}')?.toLocal();
    return SosEntry(
      id: (j['id'] as num?)?.toInt() ?? 0,
      status: '${j['status'] ?? 'sent'}',
      statusLabel: '${j['status_label'] ?? 'Sent'}',
      municipality: '${j['municipality'] ?? ''}',
      barangay: '${j['barangay'] ?? ''}',
      landmark: '${j['landmark'] ?? ''}',
      description: (j['description'] as String?)?.trim(),
      hasPhoto: j['image_url'] != null,
      hasVideo: j['video_url'] != null,
      createdAt: date(j['created_at']) ?? DateTime.now(),
      respondedAt: date(j['responded_at']),
      resolvedAt: date(j['resolved_at']),
    );
  }
}

/// Sends the resident's SOS requests and keeps the list the Safety tab shows.
class ResidentSos extends ChangeNotifier {
  ResidentSos._();
  static final ResidentSos instance = ResidentSos._();

  List<SosEntry> requests = const [];
  bool loading = false;
  bool loaded = false;
  String? error;

  bool get hasOpenRequest => requests.any((r) => r.isOpen);

  Future<void> load() async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();

    final res = await AuthService.instance.callAuthed('GET', '/resident/sos');
    final raw = res.body['sos'];
    if (res.ok && raw is List) {
      requests = raw
          .whereType<Map>()
          .map((m) => SosEntry.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      loaded = true;
    } else {
      error = res.ok ? 'Unexpected response from the server.' : res.message;
    }

    loading = false;
    notifyListeners();
  }

  /// Sends the request itself (no media). The admin is alerted as soon as
  /// this succeeds, so it must not wait for a photo or video upload.
  Future<({SosEntry? sos, String? error})> send({
    required String municipality,
    required String barangay,
    required String landmark,
    String? description,
    Position? position,
  }) async {
    final res = await AuthService.instance.callAuthed(
      'POST',
      '/resident/sos',
      body: {
        'municipality': municipality,
        'barangay': barangay,
        'landmark': landmark.trim(),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        if (position != null) ...{
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
      },
    );
    if (!res.ok) return (sos: null, error: res.message);

    final raw = res.body['sos'];
    if (raw is! Map) {
      return (sos: null, error: 'Unexpected response from the server.');
    }
    final sos = SosEntry.fromJson(Map<String, dynamic>.from(raw));
    requests = [sos, ...requests.where((r) => r.id != sos.id)];
    notifyListeners();
    return (sos: sos, error: null);
  }

  /// Uploads a photo and/or video for a request that was already sent.
  /// Returns null on success, otherwise an error message.
  Future<String?> uploadMedia(
    int id, {
    String? imagePath,
    String? videoPath,
  }) async {
    if (imagePath == null && videoPath == null) return null;
    final res = await AuthService.instance.uploadAuthed(
      '/resident/sos/$id/media',
      files: {'image': ?imagePath, 'video': ?videoPath},
    );
    if (!res.ok) return res.message;

    final raw = res.body['sos'];
    if (raw is Map) {
      final sos = SosEntry.fromJson(Map<String, dynamic>.from(raw));
      requests = [for (final r in requests) r.id == sos.id ? sos : r];
      notifyListeners();
    }
    return null;
  }

  /// A position for the request, fast: an SOS must never wait long for GPS.
  /// Returns null when location is off or not allowed.
  static Future<Position?> quickPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final last = await Geolocator.getLastKnownPosition();
      if (last != null &&
          DateTime.now().difference(last.timestamp).inMinutes < 2) {
        return last;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (e) {
      debugPrint('[sos] no position: $e');
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  void reset() {
    requests = const [];
    loading = false;
    loaded = false;
    error = null;
    notifyListeners();
  }
}
