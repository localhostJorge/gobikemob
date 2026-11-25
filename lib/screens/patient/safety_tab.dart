import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/hotlines.dart';
import '../../core/resident_sos.dart';
import '../../widgets/initials_avatar.dart';
import 'app_colors.dart';
import 'sos_tracking_screen.dart';
import 'ui_kit.dart';
import 'visit_record.dart' show formatDate, formatTime;

/// Who is coming, said simply: "Maria", "Maria and Juan", or with three or
/// more "Maria and 2 other GoBikers". The verb that follows is [onTheWayVerb].
String responderNames(List<SosResponderInfo> responders) =>
    switch (responders) {
      [] => '',
      [final a] => a.name,
      [final a, final b] => '${a.name} and ${b.name}',
      [final a, ...final rest] => '${a.name} and ${rest.length} other GoBikers',
    };

/// "is" for one GoBiker, "are" for several.
String onTheWayVerb(List<SosResponderInfo> responders) =>
    responders.length > 1 ? 'are' : 'is';

/// Status of an SOS as words, icon and color (never color alone). The colors
/// are the readable text shades.
({String label, IconData icon, Color color, String help}) sosStatusStyle(
  SosEntry sos,
  AppPalette pal,
) => switch (sos.status) {
  // Only say somebody is coming once a GoBiker has actually been sent: the admin can take a
  // request on before choosing who goes.
  'responding' =>
    sos.responders.isEmpty
        ? (
            label: 'Admin is handling it',
            icon: Icons.support_agent_rounded,
            color: pal.orangeText,
            help: 'The Go Bike admin has your request and is handling it.',
          )
        : (
            label: 'Someone is Responding',
            icon: Icons.directions_run_rounded,
            color: pal.orangeText,
            help:
                '${responderNames(sos.responders)} '
                '${onTheWayVerb(sos.responders)} on the way to help you.',
          ),
  // A cancelled request comes from the server as `resolved`, so tell them apart here.
  'resolved' when sos.cancelled => (
    label: 'Cancelled',
    icon: Icons.cancel_outlined,
    color: pal.muted,
    help: 'You cancelled this request.',
  ),
  'resolved' => (
    label: 'Resolved',
    icon: Icons.check_circle_rounded,
    color: pal.greenText,
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
    color: pal.redText,
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
                    Padding(
                      padding: EdgeInsets.fromLTRB(4, Sp.lg, 4, 0),
                      child: Text(
                        'Your past SOS requests are in History.',
                        style: T.secondary.muted(context),
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
    final s = sosStatusStyle(sos, context.pal);
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

/// Opens the map of [sos]: the resident's pin and the GoBiker coming to it.
/// [trackingPath] is where to ask for it; null for a resident's SOS.
Future<void> openSosMap(
  BuildContext context,
  SosEntry sos, {
  String? trackingPath,
}) => Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => SosTrackingScreen(sosId: sos.id, path: trackingPath),
  ),
);

/// One open SOS request: its status, what that means, who is coming, and a
/// button to cancel it.
///
/// The resident cannot mark it *resolved*: that is for the GoBiker sent to
/// help, or the admin. They can only withdraw it, after a confirmation.
///
/// A GoBiker's own emergency uses the same card, with its own [title], the
/// [noun] "emergency", [onCancel] and [trackingPath].
class SosRequestCard extends StatefulWidget {
  const SosRequestCard({
    super.key,
    required this.sos,
    this.title = 'Your SOS request',
    this.noun = 'SOS',
    this.onCancel,
    this.trackingPath,
  });

  final SosEntry sos;
  final String title;

  /// What it is called in the button, dialog and snackbar: "SOS" or
  /// "emergency".
  final String noun;

  /// Withdraws it; returns null on success, else the server's message.
  /// Without one, the resident's SOS is cancelled.
  final Future<String?> Function()? onCancel;

  /// Where its tracking map asks the server; null for a resident's SOS.
  final String? trackingPath;

  @override
  State<SosRequestCard> createState() => _SosRequestCardState();
}

class _SosRequestCardState extends State<SosRequestCard> {
  bool _cancelling = false;

  SosEntry get sos => widget.sos;
  String get _noun => widget.noun;

  /// "Cancel SOS", "Cancel emergency".
  String get _cancelLabel => 'Cancel $_noun';

  Future<void> _cancel() async {
    final coming = sos.responders;
    final ok = await showConfirm(
      context,
      title: 'Cancel your $_noun?',
      message: coming.isEmpty
          ? 'The admin will be told you no longer need help.'
          : '${responderNames(coming)} ${onTheWayVerb(coming)} on the way. '
                'They will be told not to come.',
      confirmLabel: _cancelLabel,
      cancelLabel: 'Keep it',
      destructive: true,
    );
    if (!ok || !mounted) return;

    // Cancelling takes the card off the screen, so say the result from the
    // messenger of the page, which outlives it.
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _cancelling = true);
    final cancel = widget.onCancel;
    final error = cancel != null
        ? await cancel()
        : await ResidentSos.instance.cancel(sos.id);
    if (mounted) setState(() => _cancelling = false);
    // "SOS cancelled.", "Emergency cancelled."
    final done = '${_noun[0].toUpperCase()}${_noun.substring(1)} cancelled.';
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error ?? done)));
  }

  @override
  Widget build(BuildContext context) {
    final s = sosStatusStyle(sos, context.pal);
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
                Expanded(child: Text(widget.title, style: T.rowTitle)),
                _StatusPill(sos),
              ],
            ),
            const SizedBox(height: Sp.md),
            Text(sos.place, style: T.body),
            const SizedBox(height: Sp.xs),
            Text(
              'Sent ${formatDate(sos.createdAt)}, ${formatTime(sos.createdAt)}',
              style: T.meta.muted(context),
            ),
            const SizedBox(height: Sp.md),
            Text(s.help, style: T.label.copyWith(color: s.color)),
            for (final r in sos.responders) ...[
              const SizedBox(height: Sp.md),
              _Responder(sos: sos, responder: r, color: s.color),
            ],
            if (sos.isOpen) ...[
              const SizedBox(height: Sp.lg),
              // Where the GoBiker sent to help is, live; before one is sent the map
              // shows the SOS pin and says it is waiting.
              PrimaryButton(
                label: sos.responders.isNotEmpty
                    ? 'View map · track your GoBiker'
                    : 'View map',
                icon: Icons.map_rounded,
                onPressed: () =>
                    openSosMap(context, sos, trackingPath: widget.trackingPath),
              ),
              const SizedBox(height: Sp.sm),
              SecondaryButton(
                label: _cancelLabel,
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

/// A GoBiker coming to help: who they are and that they are responding.
/// Their initials stand in when they have no photo.
class _Responder extends StatelessWidget {
  const _Responder({
    required this.sos,
    required this.responder,
    required this.color,
  });

  final SosEntry sos;
  final SosResponderInfo responder;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final name = responder.name;
    final where = responder.barangay;

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
            imageUrl: responder.photoUrl,
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
                  style: T.meta.muted(context),
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
          style: T.secondary.muted(context),
        ),
        Wrap(
          children: [
            for (final n in hotline.numbers)
              QuietButton(
                label: formatPhone(n),
                icon: Icons.call_rounded,
                // A link to call: the brand blue. Red is kept for the 911 card.
                color: context.pal.brand,
                onPressed: () => onCall(n),
              ),
          ],
        ),
      ],
    ),
  );
}
