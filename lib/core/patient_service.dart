import 'package:intl/intl.dart';

import 'auth_service.dart';

typedef _ApiCall = ({
  bool ok,
  int status,
  String message,
  Map<String, dynamic> body,
});

class PatientResult<T> {
  const PatientResult._({this.data, this.error});

  final T? data;
  final String? error;
  bool get ok => error == null;

  factory PatientResult.success(T data) => PatientResult._(data: data);
  factory PatientResult.failure(String error) => PatientResult._(error: error);
}

/// Talks to /api/gobiker/patients. Records are returned in the same map
/// format the screens already use (id, date, time, name, address, ...).
class PatientService {
  PatientService._();
  static final PatientService instance = PatientService._();

  Future<PatientResult<List<Map<String, dynamic>>>> list() async {
    final res = await AuthService.instance.callAuthed(
      'GET',
      '/gobiker/patients',
    );
    if (!res.ok) return PatientResult.failure(res.message);

    final raw = res.body['patients'];
    if (raw is! List) {
      return PatientResult.failure('Unexpected response from the server.');
    }
    final patients = raw
        .whereType<Map>()
        .map((m) => _fromApi(Map<String, dynamic>.from(m)))
        .toList();
    return PatientResult.success(patients);
  }

  Future<PatientResult<Map<String, dynamic>>> create(
    Map<String, dynamic> form, {
    String? barangay,
  }) async {
    final res = await AuthService.instance.callAuthed(
      'POST',
      '/gobiker/patients',
      body: _toApi(form, barangay),
    );
    return _single(res);
  }

  Future<PatientResult<Map<String, dynamic>>> update(
    String id,
    Map<String, dynamic> form,
  ) async {
    final res = await AuthService.instance.callAuthed(
      'PUT',
      '/gobiker/patients/$id',
      body: _toApi(form, form['barangay']?.toString()),
    );
    return _single(res);
  }

  /// Returns null on success, otherwise an error message.
  Future<String?> delete(String id) async {
    final res = await AuthService.instance.callAuthed(
      'DELETE',
      '/gobiker/patients/$id',
    );
    return res.ok ? null : res.message;
  }

  // ---------------------------------------------------------------- helpers

  PatientResult<Map<String, dynamic>> _single(_ApiCall res) {
    if (!res.ok) return PatientResult.failure(res.message);
    final p = res.body['patient'];
    if (p is! Map) {
      return PatientResult.failure('Unexpected response from the server.');
    }
    return PatientResult.success(_fromApi(Map<String, dynamic>.from(p)));
  }

  Map<String, dynamic> _toApi(Map<String, dynamic> f, String? barangay) => {
    'name': f['name'],
    'address': f['address'],
    'contact': f['contact'],
    'age': f['age'],
    'sys': f['sys'],
    'dia': f['dia'],
    'pulse': f['pulse'],
    'resp': f['resp'],
    'temp': f['temp'],
    'height': f['height'],
    'weight': f['weight'],
    if (barangay != null && barangay.isNotEmpty) 'barangay': barangay,
  };

  String _s(dynamic v) {
    if (v == null) return '';
    if (v is num && v % 1 == 0) return v.toInt().toString(); // 165.0 -> 165
    return v.toString();
  }

  Map<String, dynamic> _fromApi(Map<String, dynamic> j) {
    final recorded =
        DateTime.tryParse('${j['recorded_at'] ?? ''}')?.toLocal() ??
        DateTime.now();
    return {
      'id': _s(j['id']),
      'date': DateFormat('MMMM d, yyyy').format(recorded),
      'time': DateFormat('hh:mm a').format(recorded),
      'name': _s(j['name']),
      'address': _s(j['address']),
      'contact': _s(j['contact']),
      'age': _s(j['age']),
      'sys': _s(j['sys']),
      'dia': _s(j['dia']),
      'pulse': _s(j['pulse']),
      'resp': _s(j['resp']),
      'temp': _s(j['temp']),
      'height': _s(j['height']),
      'weight': _s(j['weight']),
      'barangay': _s(j['barangay']),
    };
  }
}
