import 'package:flutter/material.dart';

import '../../core/appointments.dart';
import '../../core/auth_service.dart';
import 'app_colors.dart';
import 'emergency_request_screen.dart' show kLocations;
import 'ui_kit.dart';

/// Where GoBikers can be looked up from: the barangays of Bugallon.
List<String> get kPickerBarangays => kLocations['Bugallon'] ?? const [];

/// Loads the GoBikers of a barangay (the resident's own when null). Replaced in tests.
typedef GobikerLoader =
    Future<({List<GobikerOption> gobikers, String? error})> Function(
      String? barangay,
    );

const _accents = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', //
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ñ': 'n', 'ç': 'c',
};

/// Lower case, no accents, one space between words: what search compares.
String plainText(String text) {
  final lower = text.toLowerCase();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    out.write(_accents[ch] ?? ch);
  }
  return out.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// The GoBikers whose name has every word of [query] in it, in any order, ignoring case
/// and accents ("pena" finds "Peña", "santos maria" finds "Maria Santos"). An empty
/// query keeps everyone.
List<GobikerOption> filterGobikers(List<GobikerOption> all, String query) {
  final words = plainText(query).split(' ').where((w) => w.isNotEmpty);
  if (words.isEmpty) return all;
  return all.where((g) {
    final name = plainText(g.name);
    return words.every(name.contains);
  }).toList();
}

/// The GoBikers of a barangay with a way to look at another barangay and to search by name.
/// Used in the sheet of the request form, and embedded in the page that suggests someone else
/// after a request was declined ([scrollable] false: the page scrolls, not the list).
class GobikerPickerBody extends StatefulWidget {
  const GobikerPickerBody({
    super.key,
    required this.startBarangay,
    required this.onPick,
    this.selectedId,
    this.excludeIds = const {},
    this.disabledIds = const {},
    this.scrollable = true,
    this.loader,
  });

  final String? startBarangay;
  final ValueChanged<GobikerOption> onPick;
  final int? selectedId;

  /// Not listed at all (for example the GoBiker who just declined).
  final Set<int> excludeIds;

  /// Listed but not choosable (they already have a request from this person).
  final Set<int> disabledIds;
  final bool scrollable;
  final GobikerLoader? loader;

  @override
  State<GobikerPickerBody> createState() => _GobikerPickerBodyState();
}

class _GobikerPickerBodyState extends State<GobikerPickerBody> {
  late String? _barangay = widget.startBarangay;
  final _search = TextEditingController();
  List<GobikerOption> _list = const [];
  bool _loading = true;
  String? _error;

  String? get _home => AuthService.instance.currentUser?.barangay;

  GobikerLoader get _load =>
      widget.loader ?? ResidentAppointments.instance.gobikers;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final barangay = _barangay;
    final res = await _load(barangay);
    // A slower answer for a barangay the resident already moved away from.
    if (!mounted || barangay != _barangay) return;
    setState(() {
      _list = res.gobikers;
      _error = res.error;
      _loading = false;
    });
  }

  List<GobikerOption> get _visible => filterGobikers(
    _list.where((g) => !widget.excludeIds.contains(g.id)).toList(),
    _search.text,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          style: T.body.copyWith(color: context.pal.ink),
          dropdownColor: context.pal.card,
          initialValue: _barangay,
          isExpanded: true,
          decoration: inputDecoration(
            context,
            'GoBikers from',
            Icons.map_outlined,
          ),
          items: [
            for (final b in kPickerBarangays)
              DropdownMenuItem(
                value: b,
                child: Text(b == _home ? '$b (your barangay)' : b),
              ),
          ],
          onChanged: (v) {
            if (v == null || v == _barangay) return;
            setState(() => _barangay = v);
            _fetch();
          },
        ),
        const SizedBox(height: Sp.md),
        TextField(
          controller: _search,
          style: T.body.copyWith(color: context.pal.ink),
          cursorColor: context.pal.ink,
          textInputAction: TextInputAction.search,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          decoration: inputDecoration(
            context,
            'Search by name',
            Icons.search_rounded,
            suffix: _search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => setState(_search.clear),
                  ),
          ),
        ),
        const SizedBox(height: Sp.sm),
        if (widget.scrollable) Flexible(child: _body()) else _body(),
      ],
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(Sp.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return EmptyState(
        title: "Couldn't load the GoBikers",
        message: _error!,
        actionLabel: 'Try again',
        onAction: _fetch,
      );
    }
    final barangay = _barangay ?? 'your barangay';
    if (_list.where((g) => !widget.excludeIds.contains(g.id)).isEmpty) {
      return EmptyState(
        title: 'No other GoBikers in $barangay',
        message: 'Choose another barangay above to see its GoBikers.',
      );
    }
    final shown = _visible;
    if (shown.isEmpty) {
      return EmptyState(
        title: 'No GoBiker matches "${_search.text.trim()}"',
        message: 'Check the spelling, or look in another barangay above.',
        actionLabel: 'Clear search',
        onAction: () => setState(_search.clear),
      );
    }

    final tiles = [for (final g in shown) _tile(g)];
    if (!widget.scrollable) {
      return Column(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0)
              Divider(height: 1, indent: 72, color: context.pal.divider),
            tiles[i],
          ],
        ],
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(horizontal: Sp.sm),
      itemCount: tiles.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, indent: 72, color: context.pal.divider),
      itemBuilder: (_, i) => tiles[i],
    );
  }

  Widget _tile(GobikerOption g) {
    final selected = g.id == widget.selectedId;
    final disabled = widget.disabledIds.contains(g.id);
    final done = g.visitsDone == 1
        ? '1 visit done'
        : '${g.visitsDone} visits done';

    return ListTile(
      enabled: !disabled,
      minVerticalPadding: 12,
      leading: CircleAvatar(
        backgroundColor: context.pal.background,
        foregroundColor: context.pal.ink,
        child: Text(g.name.isEmpty ? '?' : g.name[0].toUpperCase()),
      ),
      title: Text(
        g.name,
        style: selected
            ? T.rowTitle.copyWith(fontWeight: FontWeight.w700)
            : T.rowTitle,
      ),
      subtitle: Text(
        disabled
            ? 'Already asked, waiting for their answer'
            : '${g.barangay} · $done',
        style: T.secondary.muted(context),
      ),
      trailing: selected
          ? Icon(Icons.check_rounded, color: context.pal.ink)
          : null,
      onTap: disabled ? null : () => widget.onPick(g),
    );
  }
}

/// The request form's list: opens as a sheet, returns the GoBiker chosen (or null).
Future<GobikerOption?> showGobikerPicker(
  BuildContext context, {
  required String? startBarangay,
  int? selectedId,
  Set<int> disabledIds = const {},
  GobikerLoader? loader,
}) {
  return showModalBottomSheet<GobikerOption>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.pal.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Rd.sheet)),
    ),
    builder: (sheetContext) {
      final media = MediaQuery.of(sheetContext);
      return Padding(
        // Lifts the sheet above the keyboard, so the search field stays in view.
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: sheetContext.pal.line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Sp.gutter,
                  Sp.lg,
                  Sp.gutter,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Choose a GoBiker', style: T.heading),
                    const SizedBox(height: Sp.xs),
                    Text(
                      'GoBikers from your barangay are shown first. Search by name, '
                      'or choose one from another barangay.',
                      style: T.secondary.muted(sheetContext),
                    ),
                    const SizedBox(height: Sp.lg),
                  ],
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Sp.gutter),
                  child: GobikerPickerBody(
                    startBarangay: startBarangay,
                    selectedId: selectedId,
                    disabledIds: disabledIds,
                    loader: loader,
                    onPick: (g) => Navigator.pop(sheetContext, g),
                  ),
                ),
              ),
              SizedBox(height: Sp.md + media.padding.bottom),
            ],
          ),
        ),
      );
    },
  );
}
