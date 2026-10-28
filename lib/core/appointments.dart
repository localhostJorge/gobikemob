import 'package:flutter/foundation.dart';

import 'auth_service.dart';

/// A home check-up visit a resident requested.
class Appointment {
  const Appointment({
    required this.id,
    required this.status,
    required this.statusLabel,
    required this.barangay,
    required this.address,
    required this.preferredDate,
    required this.window,
    required this.windowLabel,
    required this.reason,
    required this.createdAt,
    this.gobikerId,
    this.gobikerName,
    this.gobikerBarangay,
    this.declineNote,
    this.residentName,
    this.residentMobile,
    this.patientId,
  });

  final int id;

  /// pending, accepted, completed, declined or cancelled.
  final String status;
  final String statusLabel;
  final String barangay;
  final String address;
  final DateTime preferredDate;

  /// morning or afternoon.
  final String window;
  final String windowLabel;
  final String reason;
  final DateTime createdAt;

  /// The GoBiker the resident chose (or who accepted an older open request).
  final int? gobikerId;
  final String? gobikerName;
  final String? gobikerBarangay;
  final String? declineNote;

  // Only sent to GoBikers.
  final String? residentName;
  final String? residentMobile;
  final int? patientId;

  bool get isOpen => status == 'pending' || status == 'accepted';

  factory Appointment.fromJson(Map<String, dynamic> j) {
    String? text(dynamic v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return Appointment(
      id: (j['id'] as num?)?.toInt() ?? 0,
      status: '${j['status'] ?? 'pending'}',
      statusLabel: '${j['status_label'] ?? ''}',
      barangay: '${j['barangay'] ?? ''}',
      address: '${j['address'] ?? ''}',
      preferredDate:
          DateTime.tryParse('${j['preferred_date'] ?? ''}') ?? DateTime.now(),
      window: '${j['preferred_window'] ?? 'morning'}',
      windowLabel: '${j['window_label'] ?? ''}',
      reason: '${j['reason'] ?? ''}',
      createdAt:
          DateTime.tryParse('${j['created_at'] ?? ''}')?.toLocal() ??
          DateTime.now(),
      gobikerId: (j['gobiker_id'] as num?)?.toInt(),
      gobikerName: text(j['gobiker_name']),
      gobikerBarangay: text(j['gobiker_barangay']),
      declineNote: text(j['decline_note']),
      residentName: text(j['resident_name']),
      residentMobile: text(j['resident_mobile']),
      patientId: (j['patient_id'] as num?)?.toInt(),
    );
  }
}

/// A GoBiker the resident can ask for a home visit.
class GobikerOption {
  const GobikerOption({
    required this.id,
    required this.name,
    required this.barangay,
    this.visitsDone = 0,
  });

  final int id;
  final String name;
  final String barangay;
  final int visitsDone;

  factory GobikerOption.fromJson(Map<String, dynamic> j) => GobikerOption(
    id: (j['id'] as num?)?.toInt() ?? 0,
    name: '${j['name'] ?? ''}',
    barangay: '${j['barangay'] ?? ''}',
    visitsDone: (j['visits_done'] as num?)?.toInt() ?? 0,
  );
}

List<Appointment> _parseList(dynamic raw) => raw is List
    ? raw
          .whereType<Map>()
          .map((m) => Appointment.fromJson(Map<String, dynamic>.from(m)))
          .toList()
    : const [];

/// Shared loading state for both stores.
abstract class _AppointmentStore extends ChangeNotifier {
  bool loading = false;
  bool loaded = false;
  String? error;

  String get _path;
  void _read(Map<String, dynamic> body);

  Future<void> load() async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();

    final res = await AuthService.instance.callAuthed('GET', _path);
    if (res.ok) {
      _read(res.body);
      loaded = true;
    } else {
      error = res.message;
    }
    loading = false;
    notifyListeners();
  }

  /// Runs an action, then reloads the list. Returns null or an error message.
  Future<String?> _act(String path, [Map<String, dynamic>? body]) async {
    final res = await AuthService.instance.callAuthed('POST', path, body: body);
    await load();
    return res.ok ? null : res.message;
  }
}

/// The GoBiker's side: requests residents sent to them, older open requests
/// in their barangay, and their own visits.
class GobikerAppointments extends _AppointmentStore {
  GobikerAppointments._();
  static final GobikerAppointments instance = GobikerAppointments._();

  /// Sent to this GoBiker by the resident: accept or decline.
  List<Appointment> requests = const [];

  /// From app versions that did not let the resident choose: anyone in the
  /// barangay may accept.
  List<Appointment> available = const [];
  List<Appointment> mine = const [];

  /// Requests to answer plus visits still to do (the dashboard counter).
  int get openCount =>
      requests.length +
      available.length +
      mine.where((a) => a.status == 'accepted').length;

  @override
  String get _path => '/gobiker/appointments';

  @override
  void _read(Map<String, dynamic> body) {
    requests = _parseList(body['requests']);
    available = _parseList(body['available']);
    mine = _parseList(body['mine']);
  }

  Future<String?> accept(int id) => _act('/gobiker/appointments/$id/accept');

  /// Declines a request sent to this GoBiker. [note] is shown to the resident.
  Future<String?> decline(int id, {String? note}) => _act(
    '/gobiker/appointments/$id/decline',
    {'note': ?((note ?? '').trim().isEmpty ? null : note!.trim())},
  );

  Future<String?> complete(int id, {int? patientId}) =>
      _act('/gobiker/appointments/$id/complete', {'patient_id': ?patientId});

  void reset() {
    requests = const [];
    available = const [];
    mine = const [];
    loaded = false;
    error = null;
    notifyListeners();
  }
}

/// The resident's side: their visit requests.
class ResidentAppointments extends _AppointmentStore {
  ResidentAppointments._();
  static final ResidentAppointments instance = ResidentAppointments._();

  List<Appointment> appointments = const [];

  Appointment? get current => appointments.where((a) => a.isOpen).firstOrNull;

  @override
  String get _path => '/resident/appointments';

  @override
  void _read(Map<String, dynamic> body) {
    appointments = _parseList(body['appointments']);
  }

  /// Approved GoBikers in [barangay] (the resident's own when null).
  Future<({List<GobikerOption> gobikers, String? error})> gobikers(
    String? barangay,
  ) async {
    final res = await AuthService.instance.callAuthed(
      'GET',
      barangay == null
          ? '/resident/gobikers'
          : '/resident/gobikers?barangay=${Uri.encodeQueryComponent(barangay)}',
    );
    if (!res.ok) return (gobikers: const <GobikerOption>[], error: res.message);
    final raw = res.body['gobikers'];
    return (
      gobikers: raw is List
          ? raw
                .whereType<Map>()
                .map(
                  (m) => GobikerOption.fromJson(Map<String, dynamic>.from(m)),
                )
                .toList()
          : const <GobikerOption>[],
      error: null,
    );
  }

  /// Sends the request to [gobikerId], who accepts or declines it.
  /// Returns null on success, otherwise an error message.
  Future<String?> request({
    required String barangay,
    required String address,
    required DateTime date,
    required String window,
    required String reason,
    required int gobikerId,
  }) {
    final d = date.toIso8601String().substring(0, 10);
    return _act('/resident/appointments', {
      'gobiker_id': gobikerId,
      'barangay': barangay,
      'address': address.trim(),
      'preferred_date': d,
      'preferred_window': window,
      'reason': reason.trim(),
    });
  }

  Future<String?> cancel(int id) => _act('/resident/appointments/$id/cancel');

  void reset() {
    appointments = const [];
    loaded = false;
    error = null;
    notifyListeners();
  }
}
