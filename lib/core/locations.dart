import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'api_config.dart';

/// One place in the location hierarchy: province, city or municipality.
class LocationEntry {
  const LocationEntry({required this.id, required this.name});

  final int id;
  final String name;

  static List<LocationEntry> list(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) {
          final id = int.tryParse('${m['id']}');
          final name = '${m['name'] ?? ''}'.trim();
          if (id == null || name.isEmpty) return null;
          return LocationEntry(id: id, name: name);
        })
        .whereType<LocationEntry>()
        .toList();
  }
}

/// One barangay, with where it hangs (city and municipality may be the same
/// place in the Philippine setup; province is always set for the ones we use).
class BarangayEntry {
  const BarangayEntry({
    required this.name,
    this.municipalityId,
    this.cityId,
    this.provinceId,
  });

  final String name;
  final int? municipalityId;
  final int? cityId;
  final int? provinceId;

  static List<BarangayEntry> list(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((m) {
      final name = '${m['name'] ?? ''}'.trim();
      return BarangayEntry(
        name: name,
        municipalityId: int.tryParse('${m['municipality_id'] ?? ''}'),
        cityId: int.tryParse('${m['city_id'] ?? ''}'),
        provinceId: int.tryParse('${m['province_id'] ?? ''}'),
      );
    }).where((b) => b.name.isNotEmpty).toList();
  }
}

/// The place hierarchy from the server (GET /locations/...): which provinces
/// exist, the cities and municipalities under one province, and the barangays
/// under one municipality. Loaded once per app start; the Bugallon list ships
/// with the app so sign-up still works with no connection.
///
/// The Philippine LGU setup layers city and municipality side by side under a
/// province; on the server a municipality always hangs off a city row, so the
/// app walks one ladder: province → city → municipality → barangay.
class Locations extends ChangeNotifier {
  Locations._();
  static final Locations instance = Locations._();

  bool _loading = false;
  bool _loaded = false;

  List<LocationEntry> _provinces = const [];

  /// Provinces that have at least one barangay in the app, name only.
  List<String> get provinceNames =>
      _provinces.map((p) => p.name).toList(growable: false);

  bool get loading => _loading;
  bool get loaded => _loaded;

  /// Fetches provinces from the API. A failure keeps the fallback, so the
  /// dropdowns never come up empty.
  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      final res = await http
          .get(
            Uri.parse('$kApiBaseUrl/locations/provinces'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        _provinces = LocationEntry.list(body['provinces']);
        _loaded = true;
      }
    } catch (_) {
      // Keep whatever we had (the offline list) on any failure.
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Cities under [provinceName]. One call, cached per province for the
  /// session.
  final Map<String, List<LocationEntry>> _citiesByProvince = {};
  final Set<String> _citiesLoading = {};

  Future<List<LocationEntry>> cities(String? provinceName) async {
    final province = provinceName?.trim();
    if (province == null || province.isEmpty) return const [];
    final cached = _citiesByProvince[province];
    if (cached != null) return cached;

    final p = _provinces.where((e) => e.name == province).firstOrNull;
    if (p == null) return const [];
    if (_citiesLoading.contains(province)) return const [];

    _citiesLoading.add(province);
    try {
      final res = await http
          .get(
            Uri.parse(
              '$kApiBaseUrl/locations/cities?province_id=${p.id}',
            ),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final cities = LocationEntry.list(body['cities']);
        _citiesByProvince[province] = cities;
        notifyListeners();
        return cities;
      }
    } catch (_) {
      // Network problem: fall through to the empty list.
    } finally {
      _citiesLoading.remove(province);
    }
    return const [];
  }

  /// Municipalities under [cityId], straight from the API each time (small
  /// lists; no cache worth the staleness).
  Future<List<LocationEntry>> municipalities(int? cityId) async {
    if (cityId == null) return const [];
    try {
      final res = await http
          .get(
            Uri.parse('$kApiBaseUrl/locations/municipalities?city_id=$cityId'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return LocationEntry.list(body['municipalities']);
      }
    } catch (_) {}
    return const [];
  }

  /// Barangays under [municipalityId]. The server orders them by their
  /// original list order, which matches the Bugallon list below.
  Future<List<String>> barangays(int? municipalityId) async {
    if (municipalityId == null) return const [];
    try {
      final res = await http
          .get(
            Uri.parse(
              '$kApiBaseUrl/locations/barangays?municipality_id=$municipalityId',
            ),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return BarangayEntry.list(
          body['barangays'],
        ).map((b) => b.name).toList(growable: false);
      }
    } catch (_) {}
    return const [];
  }

  /// Used on sign-out — the loaded data is public, so it survives, but the
  /// listeners shouldn't leak. Nothing to clear yet; here for symmetry.
  void reset() {}
}
