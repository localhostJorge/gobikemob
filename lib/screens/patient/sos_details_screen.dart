import 'package:flutter/material.dart';

import '../../core/resident_sos.dart';
import 'app_colors.dart';
import 'safety_tab.dart' show SosRequestCard;
import 'ui_kit.dart';

/// One SOS request from History: where it stands, who is coming or came, and (while it is
/// open) the button to cancel it. The card is the same one the Home and Safety tabs show.
class SosDetailsScreen extends StatefulWidget {
  const SosDetailsScreen({super.key, required this.sosId});

  final int sosId;

  @override
  State<SosDetailsScreen> createState() => _SosDetailsScreenState();
}

class _SosDetailsScreenState extends State<SosDetailsScreen> {
  @override
  void initState() {
    super.initState();
    // After the first frame, so the screens below are not told to rebuild mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ResidentSos.instance.load(); // it may have been answered since
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pal.background,
      appBar: patientAppBar(context, 'SOS request'),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: ResidentSos.instance,
          builder: (context, _) {
            final sos = ResidentSos.instance.requests
                .where((s) => s.id == widget.sosId)
                .firstOrNull;
            if (sos == null) {
              if (!ResidentSos.instance.loaded) {
                return const Center(child: CircularProgressIndicator());
              }
              return const EmptyState(
                title: 'This request is no longer here',
                message: 'It may have been cleared from your history.',
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                Sp.gutter,
                Sp.sm,
                Sp.gutter,
                Sp.xl,
              ),
              children: [SosRequestCard(sos: sos)],
            );
          },
        ),
      ),
    );
  }
}
