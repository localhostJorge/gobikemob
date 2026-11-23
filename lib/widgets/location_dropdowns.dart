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
    if (mounted) setState(() {});
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
    _loadBarangays(name);
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
      onChanged: _cities.isEmpty ? null : _onMunicipalitySelected,
      validator: (v) =>
          v == null ? 'Select your municipality' : null,
    );
  }

  // ------------------------------------------------------------------ Barangay
  void _loadBarangays(String? municipalityName) async {
    if (municipalityName == null) return;
    // Find the municipality id from the name.
    // We walk the server's hierarchy: province -> city -> municipality -> barangay.
    // The API `/locations/municipalities?city_id=ID` returns a list under a city,
    // so we need the city's id.
    try {
      // Try to find the city id from _province → _city → _municipality path.
      final city = _cities.where((c) => c.name == _cityName).firstOrNull;
      if (city == null) {
        // Fallback: the Bugallon list is always available offline.
        if (mounted) {
          setState(() => _barangayNames = kOfflineBarangays);
        }
        return;
      }
      final muni = await _locations.municipalities(city.id);
      if (!mounted) return;
      setState(() {
        _municipalities = muni;
        // Pick the first municipality if there's exactly one.
        if (_municipalities.length == 1) {
          _municipalityName = _municipalities.first.name;
          _loadBarangays(_municipalities.first.name);
        } else {
          _barangayNames = _municipalities.map((m) => m.name).toList(growable: false);
        }
      });
    } catch (_) {
      // On any error, fall back to the built-in Bugallon list.
      if (mounted) setState(() => _barangayNames = kOfflineBarangays);
    }
  }

  void _onBarangaySelected(String? name) {
    setState(() => _barangay = name);
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
      if (mounted) setState(() => _municipalities = const []);
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