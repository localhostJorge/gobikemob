import 'package:flutter/material.dart';

import '../core/locations.dart';

/// Province → City/Municipality → Barangay, three dropdowns that load their
/// child options from the API as each parent is picked. The chosen barangay is
/// the only value the server stores ([onChanged] hands it back).
///
/// With no connection, the province list is empty and the widget falls back to
/// the built-in Bugallon list ([kOfflineBarangays]), so sign-up still works.
class LocationDropdowns extends StatefulWidget {
  const LocationDropdowns({
    super.key,
    required this.onChanged,
    this.initialBarangay,
    this.validator,
  });

  /// Called with the chosen barangay (null while the person is mid-pick).
  final ValueChanged<String?> onChanged;

  /// The barangay to pre-select, when editing a profile.
  final String? initialBarangay;

  /// Validator for the barangay field.
  final String? Function(String?)? validator;

  @override
  State<LocationDropdowns> createState() => _LocationDropdownsState();
}

class _LocationDropdownsState extends State<LocationDropdowns> {
  final Locations _locations = Locations.instance;

  String? _province;
  String? _cityName;
  String? _municipalityName;
  String? _barangay;

  List<LocationEntry> _cities = const [];
  List<LocationEntry> _municipalities = const [];
  List<String> _barangayNames = const [];

  /// The barangay was chosen from the offline list while the server's
  /// provinces had not loaded. The cascade (once it appears) must not then
  /// hold it: the person is asked to pick again through the real ladder.
  bool _pickedFromOffline = false;

  @override
  void initState() {
    super.initState();
    _barangay = widget.initialBarangay;
    _locations.addListener(_onLocationsChanged);
    if (!_locations.loaded) _locations.load();
  }

  @override
  void dispose() {
    _locations.removeListener(_onLocationsChanged);
    super.dispose();
  }

  void _onLocationsChanged() {
    if (!mounted) return;
    // The provinces have arrived: the cascade takes over, and a barangay
    // picked from the offline list can no longer be shown (its dropdown now
    // lists the ones the server sends). The pick gives way; the person picks
    // again through the ladder.
    if (provinceNames.isNotEmpty && _pickedFromOffline) {
      _pickedFromOffline = false;
      if (_barangay != null) {
        setState(() => _barangay = null);
        widget.onChanged(null);
        return;
      }
    }
    setState(() {});
  }

  List<String> get provinceNames =>
      _locations.provinceNames;

  // ------------------------------------------------------------------ Province
  void _onProvinceSelected(String? name) {
    if (name == _province) return;
    setState(() {
      _province = name;
      _cityName = null;
      _municipalityName = null;
      _barangay = null;
      _cities = const [];
      _municipalities = const [];
      _barangayNames = const [];
    });
    widget.onChanged(null);
    _loadCities();
  }

  Widget _buildProvince(BuildContext context) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Province',
        hintText: 'Select your province',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.public_rounded),
      ),
      items: provinceNames
          .map((p) => DropdownMenuItem(value: p, child: Text(p)))
          .toList(growable: false),
      initialValue: _province,
      onChanged: _onProvinceSelected,
      validator: (v) => v == null ? 'Select your province' : null,
    );
  }

  // ------------------------------------------------------------------ City
  void _onCitySelected(String? name) {
    if (name == _cityName) return;
    setState(() {
      _cityName = name;
      _municipalityName = null;
      _barangay = null;
      _municipalities = const [];
      _barangayNames = const [];
    });
    widget.onChanged(null);
    _loadMunicipality();
  }

  Widget _buildCity(BuildContext context) {
    if (_province == null) return const SizedBox.shrink();
    return DropdownButtonFormField<String>(
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'City / Municipality',
        hintText: 'Select your city or municipality',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.location_city_rounded),
      ),
      items: _cities
          .map((c) => DropdownMenuItem(value: c.name, child: Text(c.name)))
          .toList(growable: false),
      initialValue: _cityName,
      onChanged: _cities.isEmpty ? null : _onCitySelected,
      validator: (v) =>
          v == null ? 'Select your city or municipality' : null,
    );
  }

  // ------------------------------------------------------------------ Municipality
  void _onMunicipalitySelected(String? name) {
    if (name == _municipalityName) return;
    setState(() {
      _municipalityName = name;
      _barangay = null;
      _barangayNames = const [];
    });
    widget.onChanged(null);
    _loadBarangays();
  }

  Widget _buildMunicipality(BuildContext context) {
    if (_cityName == null) return const SizedBox.shrink();
    return DropdownButtonFormField<String>(
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Municipality',
        hintText: 'Select your municipality',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.map_rounded),
      ),
      items: _municipalities
          .map((m) => DropdownMenuItem(value: m.name, child: Text(m.name)))
          .toList(growable: false),
      initialValue: _municipalityName,
      onChanged: _municipalities.isEmpty ? null : _onMunicipalitySelected,
      validator: (v) =>
          v == null ? 'Select your municipality' : null,
    );
  }

  // ------------------------------------------------------------------ Barangay
  /// Loads the barangays of the chosen municipality from the server.
  Future<void> _loadBarangays() async {
    final muni = _municipalities
        .where((m) => m.name == _municipalityName)
        .firstOrNull;
    if (muni == null) return;
    var names = await _locations.barangays(muni.id);
    // The request failed or came back empty: Bugallon's list ships with the
    // app, so its barangays can still be picked without a connection.
    if (names.isEmpty && muni.name == 'Bugallon') names = kOfflineBarangays;
    if (!mounted) return;
    setState(() => _barangayNames = names);
  }

  void _onBarangaySelected(String? name) {
    setState(() => _barangay = name);
    // Picked while the province list was empty (no connection): the cascade,
    // once it appears, will not hold this barangay and it has to give way.
    _pickedFromOffline = provinceNames.isEmpty;
    widget.onChanged(name);
  }

  Widget _buildBarangay(BuildContext context) {
    final offline = provinceNames.isEmpty;
    final items = offline ? kOfflineBarangays : _barangayNames;
    return DropdownButtonFormField<String>(
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Barangay',
        hintText: 'Select your barangay',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.location_on_outlined),
      ),
      items: items
          .map((n) => DropdownMenuItem(value: n, child: Text(n)))
          .toList(growable: false),
      initialValue: (items.contains(_barangay)) ? _barangay : null,
      onChanged: items.isEmpty ? null : _onBarangaySelected,
      validator: (v) => v == null ? 'Select your barangay' : null,
    );
  }

  Future<void> _loadCities() async {
    final cities = await _locations.cities(_province);
    if (!mounted) return;
    setState(() => _cities = cities);
  }

  Future<void> _loadMunicipality() async {
    if (_cityName == null) {
      if (mounted) {
        setState(() {
          _municipalities = const [];
          _municipalityName = null;
          _barangayNames = const [];
        });
      }
      return;
    }
    final city = _cities.where((c) => c.name == _cityName).firstOrNull;
    if (city == null) {
      if (mounted) setState(() => _municipalities = const []);
      return;
    }
    final muni = await _locations.municipalities(city.id);
    if (!mounted) return;
    setState(() => _municipalities = muni);
    // Only one municipality under this city (the usual case): pick it and
    // load its barangays straight away, so nobody taps twice for nothing.
    if (muni.length == 1 && _municipalityName == null) {
      _onMunicipalitySelected(muni.first.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProvince(context),
        const SizedBox(height: 16),
        _buildCity(context),
        const SizedBox(height: 16),
        _buildMunicipality(context),
        const SizedBox(height: 16),
        _buildBarangay(context),
      ],
    );
  }
}

/// Barangay names shipped with the app: Bugallon's, matching the server's
/// seeded list (and its order). Shown when the province list can't load.
const List<String> kOfflineBarangays = [
  'Angarian',
  'Asinan',
  'Bañaga',
  'Bacabac',
  'Bolaoen',
  'Buenlag',
  'Cabayaoasan',
  'Cayanga',
  'Gueset',
  'Hacienda',
  'Laguit Centro',
  'Laguit Padilla',
  'Magtaking',
  'Pangascasan',
  'Pantal',
  'Poblacion',
  'Polong',
  'Portic',
  'Salasa',
  'Salomague Norte',
  'Salomague Sur',
  'Samat',
  'San Francisco',
  'Umanday',
];