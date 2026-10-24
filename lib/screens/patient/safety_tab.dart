import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/hotlines.dart';
import '../../core/resident_sos.dart';
import 'app_colors.dart';
import 'patient_ui.dart';
import 'visit_record.dart' show formatDate, formatTime;

const _green = Color(0xFF2E9E5B);

/// Status of an SOS as text, icon and colour (never colour alone).
({String label, IconData icon, Color color, String help}) _statusStyle(
  SosEntry sos,
) => switch (sos.status) {
  'responding' => (
    label: 'Help is responding',
    icon: Icons.directions_run_rounded,
    color: AppColors.orange,
    help: 'The Go Bike admin is handling your request.',
  ),
  'resolved' => (
    label: 'Resolved',
    icon: Icons.check_circle_rounded,
    color: _green,
    help: 'The admin marked this request as resolved.',
  ),
  _ => (
    label: 'Waiting for response',
    icon: Icons.schedule_rounded,
    color: AppColors.red,
    help: 'The admin has been alerted. If it is life-threatening, call 911.',
  ),
};

/// The resident's Safety tab: their SOS requests (with live status) and
/// tap-to-call hotlines.
class SafetyTab extends StatefulWidget {
  const SafetyTab({super.key, required this.active});

  /// True while this tab is on screen; the status refreshes only then.
  final bool active;

  @override
  State<SafetyTab> createState() => _SafetyTabState();
}

class _SafetyTabState extends State<SafetyTab> {
  static const _pollEvery = Duration(seconds: 20);
  Timer? _timer;

  ResidentSos get _store => ResidentSos.instance;

  @override
  void initState() {
    super.initState();
    if (widget.active) _activate();
  }

  @override
  void didUpdateWidget(SafetyTab old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _activate();
    if (!widget.active && old.active) _timer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _activate() {
    _store.load();
    _timer?.cancel();
    // Only worth polling while a request is still open.
    _timer = Timer.periodic(_pollEvery, (_) {
      if (_store.hasOpenRequest) _store.load();
    });
  }

  Future<void> _call(String number) async {
    final ok = await launchUrl(Uri(scheme: 'tel', path: number));
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              "Couldn't open the dialer. Call ${formatPhone(number)}.",
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final open = _store.requests.where((r) => r.isOpen).toList();
        final past = _store.requests.where((r) => !r.isOpen).toList();

        return RefreshIndicator(
          color: AppColors.red,
          onRefresh: _store.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, 14),
                child: Text(
                  'Safety',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              if (_store.error != null)
                _ErrorNote(message: _store.error!, onRetry: _store.load),
              for (final sos in open) ...[
                _OpenRequestCard(sos: sos),
                const SizedBox(height: 12),
              ],
              _NationalCard(
                onCall: () => _call(kNationalEmergency.numbers.first),
              ),
              const SizedBox(height: 22),
              const _SectionLabel('EMERGENCY HOTLINES'),
              for (final h in kEmergencyHotlines)
                _HotlineCard(hotline: h, onCall: _call),
              const SizedBox(height: 14),
              const _SectionLabel('UTILITIES'),
              for (final h in kUtilityHotlines)
                _HotlineCard(hotline: h, onCall: _call),
              const SizedBox(height: 14),
              const _SectionLabel('YOUR PAST SOS REQUESTS'),
              if (!_store.loaded && _store.loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.red),
                  ),
                )
              else if (past.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                    'Requests you send with the SOS button will be listed here.',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                )
              else
                for (final sos in past) _PastRequestTile(sos: sos),
            ],
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: AppColors.textMuted,
      ),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.sos);
  final SosEntry sos;

  @override
  Widget build(BuildContext context) {
    final s = _statusStyle(sos);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: 16, color: s.color),
          const SizedBox(width: 6),
          Text(
            s.label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: s.color,
            ),
          ),
        ],
      ),
    );
  }
}

/// A request that is still open: shown first, with what it means.
class _OpenRequestCard extends StatelessWidget {
  const _OpenRequestCard({required this.sos});
  final SosEntry sos;

  @override
  Widget build(BuildContext context) {
    final s = _statusStyle(sos);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: cardDecoration().copyWith(
          border: Border.all(color: s.color.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Your SOS request',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                _StatusChip(sos),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${sos.barangay}, ${sos.municipality} · ${sos.landmark}',
              style: const TextStyle(fontSize: 13.5, color: AppColors.textDark),
            ),
            const SizedBox(height: 4),
            Text(
              'Sent ${formatDate(sos.createdAt)}, ${formatTime(sos.createdAt)}',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              s.help,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: s.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PastRequestTile extends StatelessWidget {
  const _PastRequestTile({required this.sos});
  final SosEntry sos;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: cardDecoration(14),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${sos.barangay} · ${sos.landmark}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${formatDate(sos.createdAt)}, ${formatTime(sos.createdAt)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _StatusChip(sos),
      ],
    ),
  );
}

class _NationalCard extends StatelessWidget {
  const _NationalCard({required this.onCall});
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.red,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onCall,
      child: Semantics(
        button: true,
        label: 'Call 911, national emergency hotline',
        excludeSemantics: true,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Icon(Icons.call_rounded, color: Colors.white, size: 28),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Call 911',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Life-threatening emergency? Call first.',
                      style: TextStyle(fontSize: 13, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    ),
  );
}

class _HotlineCard extends StatelessWidget {
  const _HotlineCard({required this.hotline, required this.onCall});
  final Hotline hotline;
  final void Function(String number) onCall;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
    decoration: cardDecoration(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hotline.name,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        Text(
          hotline.note == null
              ? hotline.description
              : '${hotline.description} · ${hotline.note}',
          style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            for (final n in hotline.numbers)
              TextButton.icon(
                onPressed: () => onCall(n),
                icon: const Icon(Icons.call_rounded, size: 18),
                label: Text(formatPhone(n)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.red,
                  minimumSize: const Size(48, 48),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
    decoration: cardDecoration(12).copyWith(color: AppColors.redSoft),
    child: Row(
      children: [
        const Icon(Icons.cloud_off_rounded, size: 18, color: AppColors.red),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            "Couldn't check your SOS status. $message",
            style: const TextStyle(fontSize: 12.5, color: AppColors.textDark),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.red,
            minimumSize: const Size(48, 48),
          ),
          child: const Text('Retry'),
        ),
      ],
    ),
  );
}
