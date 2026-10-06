import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/auth_service.dart';
import '../core/patient_service.dart';
import '../core/theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/fade_in_slide.dart';
import 'add_patient_screen.dart';
import 'global_state.dart';
import 'view_patient_screen.dart';

class PatientManagementScreen extends StatefulWidget {
  const PatientManagementScreen({super.key});

  @override
  State<PatientManagementScreen> createState() =>
      _PatientManagementScreenState();
}

class _PatientManagementScreenState extends State<PatientManagementScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final result = await PatientService.instance.list();
    if (!mounted) return;

    setState(() {
      _loading = false;
      if (result.ok) {
        globalPatients
          ..clear()
          ..addAll(result.data!);
        _error = null;
      } else {
        _error = result.error;
      }
    });

    // A failed refresh keeps the old list on screen, so just tell the user.
    if (!result.ok && globalPatients.isNotEmpty) {
      AppToast.show(context, result.error!, type: ToastType.error);
    }
  }

  // ------------------------------------------------------------- data helpers

  DateTime? _dateOf(Map<String, dynamic> patient) {
    try {
      return DateFormat('MMMM d, yyyy')
          .parse(patient['date']?.toString() ?? '');
    } catch (_) {
      return null;
    }
  }

  Map<String, List<Map<String, dynamic>>> get _grouped {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final patient in globalPatients) {
      final name = patient['name']?.toString().toLowerCase() ?? '';
      if (_query.isNotEmpty && !name.contains(_query.toLowerCase())) continue;
      final date = patient['date']?.toString() ?? 'Unknown date';
      grouped.putIfAbsent(date, () => []).add(patient);
    }
    return grouped;
  }

  String _dateLabel(String date) {
    try {
      final d = DateFormat('MMMM d, yyyy').parse(date);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final diff = today.difference(DateTime(d.year, d.month, d.day)).inDays;
      if (diff == 0) return 'Today';
      if (diff == 1) return 'Yesterday';
    } catch (_) {}
    return date;
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  // ----------------------------------------------------------------- actions

  Future<void> _openPatientViewer(Map<String, dynamic> patient) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewPatientScreen(patient: patient),
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      if (result['action'] == 'delete') {
        globalPatients.removeWhere((p) => p['id'] == patient['id']);
        AppToast.show(context, 'Record deleted.', type: ToastType.success);
      } else if (result['action'] == 'update') {
        final index = globalPatients.indexWhere(
          (p) => p['id'] == patient['id'],
        );
        if (index != -1) globalPatients[index] = result['data'];
        AppToast.show(context, 'Record updated.', type: ToastType.success);
      }
    });
  }

  Future<void> _addPatient() async {
    final created = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => AddPatientScreen(
          barangay: AuthService.instance.currentUser?.barangay,
        ),
      ),
    );
    if (created == null || !mounted) return;

    setState(() => globalPatients.insert(0, created));
    AppToast.show(context, 'Patient record saved.', type: ToastType.success);
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    final grouped = _grouped;
    final dates = grouped.keys.toList()
      ..sort((a, b) {
        try {
          final da = DateFormat('MMMM d, yyyy').parse(a);
          final db = DateFormat('MMMM d, yyyy').parse(b);
          return db.compareTo(da); // newest first
        } catch (_) {
          return 0;
        }
      });

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          'Patients',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPatient,
        backgroundColor: AppTheme.blue,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Patient',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(child: _buildBody(theme, muted, grouped, dates)),
    );
  }

  Widget _buildBody(
    ThemeData theme,
    Color muted,
    Map<String, List<Map<String, dynamic>>> grouped,
    List<String> dates,
  ) {
    // 1) First load: centered loader
    if (_loading && globalPatients.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // 2) Could not load and nothing to show: error with Retry
    if (_error != null && globalPatients.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 56, color: muted),
              const SizedBox(height: 16),
              const Text(
                "Couldn't load patients",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: muted),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // 3) Dashboard: overview + search + records (pull down to refresh)
    return RefreshIndicator(
      onRefresh: () => _load(showSpinner: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          FadeInSlide(child: _overview(theme, muted)),
          const SizedBox(height: 24),
          if (globalPatients.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: _emptyState(
                muted,
                icon: Icons.assignment_ind_outlined,
                title: 'No patient records yet',
                body: 'Records you add during a ronda will appear here.',
              ),
            )
          else ...[
            FadeInSlide(
              delay: const Duration(milliseconds: 80),
              child: _recordsHeader(muted),
            ),
            const SizedBox(height: 16),
            if (dates.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: _emptyState(
                  muted,
                  icon: Icons.search_off_rounded,
                  title: 'No matches',
                  body: 'No patient matches "$_query".',
                ),
              )
            else
              for (var i = 0; i < dates.length; i++)
                FadeInSlide(
                  delay: Duration(milliseconds: 60 * (i > 5 ? 5 : i)),
                  child: _dateGroup(theme, muted, dates[i], grouped[dates[i]]!),
                ),
          ],
        ],
      ),
    );
  }

  // --------------------------------------------------------------- dashboard

  Widget _overview(ThemeData theme, Color muted) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(const Duration(days: 6));

    var todayCount = 0;
    var weekCount = 0;
    for (final p in globalPatients) {
      final d = _dateOf(p);
      if (d == null) continue;
      if (!d.isBefore(today)) todayCount++;
      if (!d.isBefore(weekStart)) weekCount++;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('OVERVIEW', muted),
        Row(
          children: [
            Expanded(
              child: _statCard(
                theme,
                muted,
                icon: Icons.folder_shared_rounded,
                color: AppTheme.blue,
                value: '${globalPatients.length}',
                label: 'Total records',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                theme,
                muted,
                icon: Icons.today_rounded,
                color: AppTheme.successGreen,
                value: '$todayCount',
                label: 'Today',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                theme,
                muted,
                icon: Icons.date_range_rounded,
                color: AppTheme.orange,
                value: '$weekCount',
                label: 'This week',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _recordsHeader(Color muted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('RECORDS', muted),
        TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v.trim()),
          decoration: InputDecoration(
            hintText: 'Search by name',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text, Color muted) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: muted,
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration(ThemeData theme) => BoxDecoration(
    color: theme.cardColor,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: theme.dividerColor),
  );

  Widget _statCard(
    ThemeData theme,
    Color muted, {
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: _cardDecoration(theme),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(
    Color muted, {
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: muted),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateGroup(
    ThemeData theme,
    Color muted,
    String date,
    List<Map<String, dynamic>> items,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Row(
              children: [
                Text(
                  _dateLabel(date).toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: muted,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${items.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: _cardDecoration(theme),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  InkWell(
                    onTap: () => _openPatientViewer(items[i]),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppTheme.blue.withValues(
                              alpha: 0.12,
                            ),
                            child: Text(
                              _initials(items[i]['name']?.toString() ?? ''),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.blue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  items[i]['name']?.toString() ?? 'Unnamed',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${items[i]['time'] ?? ''} • Age ${items[i]['age'] ?? '-'}',
                                  style: TextStyle(fontSize: 12, color: muted),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: muted),
                        ],
                      ),
                    ),
                  ),
                  if (i < items.length - 1)
                    Divider(
                      height: 1,
                      indent: 14,
                      endIndent: 14,
                      color: theme.dividerColor,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
