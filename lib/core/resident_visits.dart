import 'package:flutter/foundation.dart';

import '../screens/patient/visit_record.dart';
import 'auth_service.dart';

/// The signed-in resident's check-ups, loaded from GET /api/resident/visits.
/// The History tab and Medical History screen both listen to it.
class ResidentVisits extends ChangeNotifier {
  ResidentVisits._();
  static final ResidentVisits instance = ResidentVisits._();

  List<VisitRecord> visits = const [];

  /// True while a request is running.
  bool loading = false;

  /// True once a load has succeeded (so an empty list means "no visits yet").
  bool loaded = false;

  /// The last error, or null. Old visits stay visible when a refresh fails.
  String? error;

  Future<void> load() async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();

    final res = await AuthService.instance.callAuthed(
      'GET',
      '/resident/visits',
    );
    final raw = res.body['visits'];
    if (res.ok && raw is List) {
      visits = raw
          .whereType<Map>()
          .map((m) => VisitRecord.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      loaded = true;
    } else {
      error = res.ok ? 'Unexpected response from the server.' : res.message;
    }

    loading = false;
    notifyListeners();
  }

  /// Forget everything on logout, so the next account starts clean.
  void reset() {
    visits = const [];
    loading = false;
    loaded = false;
    error = null;
    notifyListeners();
  }
}
