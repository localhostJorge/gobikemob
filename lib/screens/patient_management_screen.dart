import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
    final newPatient = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => const AddPatientScreen()),
    );
    if (newPatient == null || !mounted) return;

    setState(() {
      newPatient['id'] = DateTime.now().millisecondsSinceEpoch.toString();
      newPatient['date'] = DateFormat('MMMM d, yyyy').format(DateTime.now());
      globalPatients.add(newPatient);
    });
    AppToast.show(context, 'Patient record saved.', type: ToastType.success);
  }

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
      body: SafeArea(
        child: Column(
          children: [
            if (globalPatients.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
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
              ),
            Expanded(
              child: globalPatients.isEmpty
                  ? _emptyState(
                      muted,
                      icon: Icons.assignment_ind_outlined,
                      title: 'No patient records yet',
                      body: 'Records you add during a ronda will appear here.',
                    )
                  : dates.isEmpty
                  ? _emptyState(
                      muted,
                      icon: Icons.search_off_rounded,
                      title: 'No matches',
                      body: 'No patient matches "$_query".',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      itemCount: dates.length,
                      itemBuilder: (context, index) {
                        final date = dates[index];
                        final items = grouped[date]!;
                        return FadeInSlide(
                          delay: Duration(
                            milliseconds: 60 * (index > 5 ? 5 : index),
                          ),
                          child: _dateGroup(theme, muted, date, items),
                        );
                      },
                    ),
            ),
          ],
        ),
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
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor),
            ),
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
