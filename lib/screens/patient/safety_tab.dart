import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/hotlines.dart';
import '../../core/resident_sos.dart';
import 'app_colors.dart';
import 'ui_kit.dart';
import 'visit_record.dart' show formatDate, formatTime;

/// Status of an SOS as words, icon and color (never color alone). The colors
/// are the readable text shades.
({String label, IconData icon, Color color, String help}) sosStatusStyle(
  SosEntry sos,
) => switch (sos.status) {
  'responding' => (
    label: 'Someone is Responding',
    icon: Icons.directions_run_rounded,
    color: AppColors.orangeText,
    help: 'The Go Bike admin is handling your request.',
  ),
  'resolved' => (
    label: 'Resolved',
    icon: Icons.check_circle_rounded,
    color: AppColors.greenText,
    help: sos.resolvedByResident
        ? 'You marked this request as resolved.'
        : 'The admin marked this request as resolved.',
  ),
  _ => (
    label: 'Waiting for response',
    icon: Icons.schedule_rounded,
    color: AppColors.redText,
    help: 'The admin has been alerted. If it is life-threatening, call 911.',
  ),
};

/// Refreshes the SOS list every 20 seconds while a screen is showing and a
/// request is still open.
mixin _SosPolling<W extends StatefulWidget> on State<W> {
  static const _pollEvery = Duration(seconds: 20);
  Timer? _timer;

  void startPolling() {
    ResidentSos.instance.load();
    _timer?.cancel();
    _timer = Timer.periodic(_pollEvery, (_) {
      if (ResidentSos.instance.hasOpenRequest) ResidentSos.instance.load();
    });
  }

  void stopPolling() => _timer?.cancel();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// The resident's Safety tab: the open SOS (if any), Call 911 and the
/// tap-to-call hotlines. Past requests are in History.
class SafetyTab extends StatefulWidget {
  const SafetyTab({super.key, required this.active});

  /// True while this tab is on screen; the status refreshes only then.
  final bool active;

  @override
  State<SafetyTab> createState() => _SafetyTabState();
}

class _SafetyTabState extends State<SafetyTab> with _SosPolling {
  ResidentSos get _store => ResidentSos.instance;

  @override
  void initState() {
    super.initState();
    if (widget.active) startPolling();
  }

  @override
  void didUpdateWidget(SafetyTab old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) startPolling();
    if (!widget.active && old.active) stopPolling();
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TabHeader('Safety'),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.red,
                onRefresh: _store.load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    Sp.gutter,
                    Sp.sm,
                    Sp.gutter,
                    Sp.xl,
                  ),
                  children: [
                    if (_store.error != null)
                      InlineNotice(
                        message: "Couldn't check your SOS status.",
                        onAction: _store.load,
                      ),
                    for (final sos in open) ...[
                      SosRequestCard(sos: sos),
                      const SizedBox(height: Sp.lg),
                    ],
                    _CallBar(
                      onCall: () => _call(kNationalEmergency.numbers.first),
                    ),
                    const SizedBox(height: Sp.xl),
                    const SectionHeader('Emergency hotlines'),
                    CardGroup(
                      children: [
                        for (final h in kEmergencyHotlines)
                          _HotlineRow(hotline: h, onCall: _call),
                      ],
                    ),
                    const SizedBox(height: Sp.xl),
                    const SectionHeader('Power and water'),
                    CardGroup(
                      children: [
                        for (final h in kUtilityHotlines)
                          _HotlineRow(hotline: h, onCall: _call),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(4, Sp.lg, 4, 0),
                      child: Text(
                        'Your past SOS requests are in History.',
                        style: T.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------- SOS card

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.sos);
  final SosEntry sos;

  @override
  Widget build(BuildContext context) {
    final s = sosStatusStyle(sos);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: 16, color: s.color),
          const SizedBox(width: 6),
          Text(s.label, style: T.label.copyWith(color: s.color)),
        ],
      ),
    );
  }
}

/// The resident's open SOS requests on the Home tab, right under the SOS
/// button. Refreshes while Home is on screen and a request is still open.
class HomeSosStatus extends StatefulWidget {
  const HomeSosStatus({super.key, required this.active});

  /// True while the Home tab is on screen.
  final bool active;

  @override
  State<HomeSosStatus> createState() => _HomeSosStatusState();
}

class _HomeSosStatusState extends State<HomeSosStatus> with _SosPolling {
  @override
  void initState() {
    super.initState();
    if (widget.active) startPolling();
  }

  @override
  void didUpdateWidget(HomeSosStatus old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) startPolling();
    if (!widget.active && old.active) stopPolling();
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
              const SizedBox(height: Sp.xl),
              SosRequestCard(sos: sos),
            ],
          ],
        );
      },
    );
  }
}

/// One open SOS request with its status, what it means, and a way to close it.
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
    final ok = await showConfirm(
      context,
      title: 'Mark as resolved?',
      message:
          'Do this only if you no longer need help. The admin will see that '
          'you closed this request.',
      confirmLabel: 'Yes, resolved',
      cancelLabel: 'I still need help',
      confirmColor: AppColors.greenText,
    );
    if (!ok || !mounted) return;

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
      child: AppCard(
        borderColor: s.color.withValues(alpha: 0.55),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Your SOS request', style: T.rowTitle),
                ),
                _StatusPill(sos),
              ],
            ),
            const SizedBox(height: Sp.md),
            Text(
              '${sos.barangay}, ${sos.municipality} · ${sos.landmark}',
              style: T.body,
            ),
            const SizedBox(height: Sp.xs),
            Text(
              'Sent ${formatDate(sos.createdAt)}, ${formatTime(sos.createdAt)}',
              style: T.meta,
            ),
            const SizedBox(height: Sp.md),
            Text(s.help, style: T.label.copyWith(color: s.color)),
            if (sos.isOpen) ...[
              const SizedBox(height: Sp.lg),
              SecondaryButton(
                label: _resolving ? 'Resolving…' : 'Mark as resolved',
                icon: Icons.check_circle_outline_rounded,
                loading: _resolving,
                onPressed: _resolve,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- hotlines

/// Call 911: the main action of the Safety tab.
class _CallBar extends StatelessWidget {
  const _CallBar({required this.onCall});
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Call 911, the national emergency hotline',
    excludeSemantics: true,
    child: Material(
      color: AppColors.redButton,
      borderRadius: BorderRadius.circular(Rd.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rd.card),
        onTap: onCall,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: Sp.lg, vertical: 18),
          child: Row(
            children: [
              Icon(Icons.call_rounded, color: Colors.white, size: 26),
              SizedBox(width: Sp.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Call 911',
                      style: TextStyle(
                        fontSize: 20,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Life-threatening emergency? Call first.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
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

class _HotlineRow extends StatelessWidget {
  const _HotlineRow({required this.hotline, required this.onCall});
  final Hotline hotline;
  final void Function(String number) onCall;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Sp.lg, 14, Sp.sm, Sp.xs),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(hotline.name, style: T.rowTitle),
        Text(
          hotline.note == null
              ? hotline.description
              : '${hotline.description} · ${hotline.note}',
          style: T.secondary,
        ),
        Wrap(
          children: [
            for (final n in hotline.numbers)
              QuietButton(
                label: formatPhone(n),
                icon: Icons.call_rounded,
                color: AppColors.redText,
                onPressed: () => onCall(n),
              ),
          ],
        ),
      ],
    ),
  );
}
