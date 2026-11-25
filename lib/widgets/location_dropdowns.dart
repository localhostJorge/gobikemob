import 'package:flutter/material.dart';

import '../core/locations.dart';
import 'app_text_field.dart';

/// Province → City/Municipality → Barangay, three dropdowns that load their
/// child options from the API as each parent is picked. The chosen barangay is
/// the only value the server stores ([onChanged] hands it back).
///
/// With no connection, the province list is empty and the widget falls back to
/// the built-in Bugallon list ([kOfflineBarangays]), so sign-up still works.
///
/// The fields are [AppDropdownField]s: the same look as every other field on
/// the form (label above, Roboto 15 regular inside), not Material's floating
/// label and default weight.
class LocationDropdowns extends StatefulWidget {
  const LocationDropdowns({
    super.key,
    required this.onChanged,
    this.initialBarangay,
    this.initialProvince,
    this.initialCity,
    this.initialMunicipality,
    this.validator,
  });

  /// Called with the chosen barangay (null while the person is mid-pick).
  final ValueChanged<String?> onChanged;

  /// The barangay to pre-select, when editing a profile.
  final String? initialBarangay;

  /// Where [initialBarangay] hangs, by name, so the province → city →
  /// municipality ladder can be rebuilt when editing a profile. Without a
  /// province the ladder starts empty, as on sign-up.
  final String? initialProvince;
  final String? initialCity;
  final String? initialMunicipality;

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

  /// The saved place ([LocationDropdowns.initialProvince] and below) still has
  /// to be walked down once the provinces are in.
  bool _restorePending = false;

  @override
  void initState() {
    super.initState();
    _barangay = widget.initialBarangay;
    _restorePending = (widget.initialProvince ?? '').trim().isNotEmpty;
    _locations.addListener(_onLocationsChanged);
    if (!_locations.loaded) _locations.load();
    // The provinces came in earlier (another form this session): restore now,
    // after this first frame.
    if (_restorePending && provinceNames.isNotEmpty) {
      Future.microtask(_restore);
    }
  }

  @override
  void dispose() {
    _locations.removeListener(_onLocationsChanged);
    super.dispose();
  }

  void _onLocationsChanged() {
    if (!mounted) return;
    if (_restorePending && provinceNames.isNotEmpty) {
      _restore();
      return;
    }
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

  List<String> get provinceNames => _locations.provinceNames;

  /// [name] as it appears in [names]: exact, else ignoring case and spaces.
  static String? _match(Iterable<String> names, String? name) {
    final want = name?.trim().toLowerCase();
    if (want == null || want.isEmpty) return null;
    for (final n in names) {
      if (n == name) return n;
    }
    for (final n in names) {
      if (n.trim().toLowerCase() == want) return n;
    }
    return null;
  }

  // ------------------------------------------------------------------ Restore
  /// Rebuilds the saved place: province, then its cities, then the city, its
  /// municipality and that municipality's barangays, keeping the saved
  /// barangay picked the whole way (the screen is never told it was cleared).
  /// A step that no longer matches the server's list stops the walk there,
  /// leaving the person to pick the rest.
  Future<void> _restore() async {
    if (!_restorePending || !mounted) return;
    _restorePending = false;
    final province = _match(provinceNames, widget.initialProvince);
    if (province == null) return;

    setState(() => _province = province);
    await _loadCities();
    if (!mounted || _province != province || _cityName != null) return;

    final cityNames = _cities.map((c) => c.name);
    // City and municipality usually share a name; either finds the town.
    final city =
        _match(cityNames, widget.initialCity) ??
        _match(cityNames, widget.initialMunicipality);
    if (city == null) return;

    setState(() => _cityName = city);
    await _loadMunicipality(
      preferred: widget.initialMunicipality,
      keepBarangay: true,
    );
    if (!mounted || _cityName != city) return;

    // Re-apply the saved barangay in the spelling the server now lists.
    final barangay = _match(_barangayNames, widget.initialBarangay);
    if (barangay != null && _barangay != barangay) {
      setState(() => _barangay = barangay);
      widget.onChanged(barangay);
    }
  }

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
    return AppDropdownField(
      label: 'Province',
      hint: 'Select your province',
      icon: Icons.public_rounded,
      items: provinceNames,
      value: _province,
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
    return AppDropdownField(
      label: 'City / Municipality',
      hint: 'Select your city or municipality',
      icon: Icons.location_city_rounded,
      items: _cities.map((c) => c.name).toList(growable: false),
      value: _cityName,
      onChanged: _cities.isEmpty ? null : _onCitySelected,
      validator: (v) => v == null ? 'Select your city or municipality' : null,
    );
  }

  // ------------------------------------------------------------------ Municipality
  // Not shown: each City / Municipality on the server has exactly one
  // municipality row of the same name, so a second dropdown would only repeat
  // the town already picked. It is chosen here, out of sight, so the
  // barangays can load from it.
  ///
  /// [keepBarangay] is set while the saved place is restored: the saved
  /// barangay stays picked instead of being cleared.
  Future<void> _onMunicipalitySelected(
    String? name, {
    bool keepBarangay = false,
  }) async {
    if (name == _municipalityName) return;
    setState(() {
      _municipalityName = name;
      if (!keepBarangay) _barangay = null;
      _barangayNames = const [];
    });
    if (!keepBarangay) widget.onChanged(null);
    await _loadBarangays();
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
    return AppDropdownField(
      label: 'Barangay',
      hint: 'Select your barangay',
      icon: Icons.location_on_outlined,
      items: items,
      value: items.contains(_barangay) ? _barangay : null,
      onChanged: items.isEmpty ? null : _onBarangaySelected,
      validator:
          widget.validator ?? (v) => v == null ? 'Select your barangay' : null,
    );
  }

  Future<void> _loadCities() async {
    final cities = await _locations.cities(_province);
    if (!mounted) return;
    setState(() => _cities = cities);
  }

  /// Loads the chosen city's municipalities and picks one: [preferred] when it
  /// is listed, else the city's own (same name), else the first.
  Future<void> _loadMunicipality({
    String? preferred,
    bool keepBarangay = false,
  }) async {
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
    // The person switched town while this was loading: a newer load wins.
    if (!mounted || _cityName != city.name) return;
    setState(() => _municipalities = muni);
    // There is no Municipality dropdown: take the city's own municipality
    // (the one with its name, else the first) and load its barangays.
    if (muni.isNotEmpty && _municipalityName == null) {
      final names = muni.map((m) => m.name);
      final own =
          _match(names, preferred) ??
          muni.where((m) => m.name == city.name).firstOrNull?.name ??
          muni.first.name;
      await _onMunicipalitySelected(own, keepBarangay: keepBarangay);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProvince(context),
        const SizedBox(height: 16),
        // The city field only appears once a province is picked; skip its gap
        // until then so the barangay field doesn't sit under an empty space.
        if (_province != null) ...[
          _buildCity(context),
          const SizedBox(height: 16),
        ],
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
