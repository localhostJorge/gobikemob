import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/hotlines.dart';
import '../../core/resident_sos.dart';
import '../../widgets/initials_avatar.dart';
import 'app_colors.dart';
import 'ui_kit.dart';
import 'visit_record.dart' show formatDate, formatTime;

/// Status of an SOS as words, icon and color (never color alone). The colors
/// are the readable text shades.
({String label, IconData icon, Color color, String help}) sosStatusStyle(
  SosEntry sos,
) => switch (sos.status) {
  // Only say somebody is coming once a GoBiker has actually been sent: the admin can take a
  // request on before choosing who goes.
  'responding' =>
    sos.responderName == null
        ? (
            label: 'Admin is handling it',
            icon: Icons.support_agent_rounded,
            color: AppColors.orangeText,
            help: 'The Go Bike admin has your request and is handling it.',
          )
        : (
            label: 'Someone is Responding',
            icon: Icons.directions_run_rounded,
            color: AppColors.orangeText,
            help: '${sos.responderName} is on the way to help you.',
          ),
  // A cancelled request comes from the server as `resolved`, so tell them apart here.
  'resolved' when sos.cancelled => (
    label: 'Cancelled',
    icon: Icons.cancel_outlined,
    color: AppColors.textMuted,
    help: 'You cancelled this request.',
  ),
  'resolved' => (
    label: 'Resolved',
    icon: Icons.check_circle_rounded,
    color: AppColors.greenText,
    help: switch (sos) {
      _ when sos.resolvedByResident => 'You marked this request as resolved.',
      _ when sos.responderName != null =>
        '${sos.responderName} marked this request as resolved.',
      _ => 'The admin marked this request as resolved.',
    },
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

/// One open SOS request: its status, what that means, who is coming, and a
/// button to cancel it.
///
/// The resident cannot mark it *resolved*: that is for the GoBiker sent to
/// help, or the admin. They can only withdraw it, after a confirmation.
class SosRequestCard extends StatefulWidget {
  const SosRequestCard({super.key, required this.sos});

  final SosEntry sos;

  @override
  State<SosRequestCard> createState() => _SosRequestCardState();
}

class _SosRequestCardState extends State<SosRequestCard> {
  bool _cancelling = false;

  SosEntry get sos => widget.sos;

  Future<void> _cancel() async {
    final responder = sos.responderName;
    final ok = await showConfirm(
      context,
      title: 'Cancel your SOS?',
      message: responder == null
          ? 'The admin will be told you no longer need help.'
          : '$responder is on the way. They will be told not to come.',
      confirmLabel: 'Cancel SOS',
      cancelLabel: 'Keep it',
      destructive: true,
    );
    if (!ok || !mounted) return;

    // Cancelling takes the card off the screen, so say the result from the
    // messenger of the page, which outlives it.
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _cancelling = true);
    final error = await ResidentSos.instance.cancel(sos.id);
    if (mounted) setState(() => _cancelling = false);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error ?? 'SOS cancelled.')));
  }

  @override
  Widget build(BuildContext context) {
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
            Text(sos.place, style: T.body),
            const SizedBox(height: Sp.xs),
            Text(
              'Sent ${formatDate(sos.createdAt)}, ${formatTime(sos.createdAt)}',
              style: T.meta,
            ),
            const SizedBox(height: Sp.md),
            Text(s.help, style: T.label.copyWith(color: s.color)),
            if (sos.responderName != null) ...[
              const SizedBox(height: Sp.md),
              _Responder(sos: sos, color: s.color),
            ],
            if (sos.isOpen) ...[
              const SizedBox(height: Sp.lg),
              SecondaryButton(
                label: 'Cancel SOS',
                icon: Icons.close_rounded,
                destructive: true,
                loading: _cancelling,
                onPressed: _cancel,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The GoBiker coming to help: who they are and that they are responding.
/// There are no photos on the server, so their initials stand in for one.
class _Responder extends StatelessWidget {
  const _Responder({required this.sos, required this.color});

  final SosEntry sos;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final name = sos.responderName ?? '';
    final where = sos.responderBarangay;

    return Container(
      padding: const EdgeInsets.all(Sp.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          InitialsAvatar(
            name,
            imageUrl: sos.responderPhotoUrl,
            radius: 20,
            color: color,
          ),
          const SizedBox(width: Sp.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: T.rowTitle),
                const SizedBox(height: 2),
                Text(
                  [
                    sos.isOpen ? 'Responding' : 'Responded',
                    if (where != null && where.isNotEmpty) 'GoBiker · $where',
                  ].join(' · '),
                  style: T.meta,
                ),
              ],
            ),
          ),
        ],
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
