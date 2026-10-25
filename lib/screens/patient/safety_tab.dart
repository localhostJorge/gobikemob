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
({String label, IconData icon, Color color, String help}) sosStatusStyle(
  SosEntry sos,
) => switch (sos.status) {
  'responding' => (
    label: 'Someone is Responding',
    icon: Icons.directions_run_rounded,
    color: AppColors.orange,
    help: 'The Go Bike admin is handling your request.',
  ),
  'resolved' => (
    label: 'Resolved',
    icon: Icons.check_circle_rounded,
    color: _green,
    help: sos.resolvedByResident
        ? 'You marked this request as resolved.'
        : 'The admin marked this request as resolved.',
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
        // Past requests are in History; here only what still needs attention.
        final open = _store.requests.where((r) => r.isOpen).toList();

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
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              if (_store.error != null)
                _ErrorNote(message: _store.error!, onRetry: _store.load),
              for (final sos in open) ...[
                SosRequestCard(sos: sos),
                const SizedBox(height: 12),
              ],
              _NationalCard(
                onCall: () => _call(kNationalEmergency.numbers.first),
              ),
              const SizedBox(height: 22),
              const _SectionLabel('Emergency hotlines'),
              for (final h in kEmergencyHotlines)
                _HotlineCard(hotline: h, onCall: _call),
              const SizedBox(height: 14),
              const _SectionLabel('Power and water'),
              for (final h in kUtilityHotlines)
                _HotlineCard(hotline: h, onCall: _call),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Text(
                  'Your past SOS requests are in History.',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ),
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
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
      ),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.sos);
  final SosEntry sos;

  @override
  Widget build(BuildContext context) {
    final s = sosStatusStyle(sos);
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
/// The resident's open SOS requests on the Home tab, right under the SOS
/// button, so they see the status without opening the Safety tab. Refreshes
/// every 20 seconds while Home is on screen and a request is still open.
class HomeSosStatus extends StatefulWidget {
  const HomeSosStatus({super.key, required this.active});

  /// True while the Home tab is on screen.
  final bool active;

  @override
  State<HomeSosStatus> createState() => _HomeSosStatusState();
}

class _HomeSosStatusState extends State<HomeSosStatus> {
  static const _pollEvery = Duration(seconds: 20);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.active) _activate();
  }

  @override
  void didUpdateWidget(HomeSosStatus old) {
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
    ResidentSos.instance.load();
    _timer?.cancel();
    _timer = Timer.periodic(_pollEvery, (_) {
      if (ResidentSos.instance.hasOpenRequest) ResidentSos.instance.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ResidentSos.instance,
      builder: (context, _) {
        final open = ResidentSos.instance.requests.where((r) => r.isOpen);
        return Column(
          children: [
            for (final sos in open) ...[
              const SizedBox(height: 20),
              SosRequestCard(sos: sos),
            ],
          ],
        );
      },
    );
  }
}

/// One open SOS request with its status and what it means.
class SosRequestCard extends StatefulWidget {
  const SosRequestCard({super.key, required this.sos});
  final SosEntry sos;

  @override
  State<SosRequestCard> createState() => _SosRequestCardState();
}

class _SosRequestCardState extends State<SosRequestCard> {
  bool _resolving = false;

  /// The resident no longer needs help: close the request after a check.
  Future<void> _resolve() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as resolved?'),
        content: const Text(
          'Do this only if you no longer need help. The admin will see that '
          'you closed this request.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('I still need help'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Yes, resolved',
              style: TextStyle(color: _green, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _resolving = true);
    final error = await ResidentSos.instance.resolve(widget.sos.id);
    if (!mounted) return;
    setState(() => _resolving = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(error ?? 'SOS request resolved. Glad you are okay.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final sos = widget.sos;
    final s = sosStatusStyle(sos);
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
            if (sos.isOpen) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _resolving ? null : _resolve,
                  icon: _resolving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(
                    _resolving ? 'Resolving…' : 'Mark as resolved',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _green,
                    side: const BorderSide(color: _green),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
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
