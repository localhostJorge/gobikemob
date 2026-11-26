import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../core/auth_service.dart';
import '../../core/fix.dart';
import '../../core/location_gate.dart';
import '../../core/resident_sos.dart';
import '../../core/sos_questions.dart';
import '../../widgets/sos_severity.dart';

import 'app_colors.dart';
import 'ui_kit.dart';

class EmergencyRequestScreen extends StatefulWidget {
  const EmergencyRequestScreen({super.key});

  @override
  State<EmergencyRequestScreen> createState() => _EmergencyRequestScreenState();
}

class _EmergencyRequestScreenState extends State<EmergencyRequestScreen> {
  final _description = TextEditingController();
  final _landmark = TextEditingController();

  /// Both asked with nothing picked: a guess the resident never made must not reach the admin.
  String? _severity;
  String? _injured;
  final _picker = ImagePicker();

  /// Shows "Required" under empty fields after the resident taps Send.
  bool _showErrors = false;

  XFile? _image;
  XFile? _video;
  VideoPlayerController? _videoCtrl;
  bool _sending = false;

  /// The phone's position lookup, started when the screen opens.
  Future<Position?>? _position;

  /// The best reading so far, kept while the form is open: the phone gets surer of where it
  /// is over the first seconds, and the pin should be the best it managed, not the first.
  Fix? _best;
  StreamSubscription<Position>? _updates;

  /// Why no position can be had on this phone (null if location is available).
  LocationState? _locationProblem;

  /// Whether we currently have a valid location fix to send with the SOS.
  bool get _hasLocationFix => _best != null;

  /// Send waits for the pin and for both answers.
  bool get _canSend => _hasLocationFix && _severity != null && _injured != null;

  // The server accepts videos up to 50 MB.
  static const int _maxVideoBytes = 50 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    _startLookup(); // start looking for the phone's position now
  }

  void _startLookup() {
    final lookup = ResidentSos.positionSource();
    _position = lookup;
    lookup.then((position) async {
      if (!mounted || !identical(_position, lookup)) return;
      if (position != null) {
        setState(() => _best = Fix.better(_best, Fix(position)));
      }
      // Only reads the phone's state: it never asks the phone anything.
      final state = await LocationGate.instance.check();
      if (!mounted || !identical(_position, lookup)) return;
      if (state != LocationState.ready) {
        // Nothing can come back: say why, so they can fix it.
        if (position == null) setState(() => _locationProblem = state);
        return;
      }
      // Keep listening while they fill the form: a better reading replaces a rougher one.
      _updates?.cancel();
      _updates = ResidentSos.positionUpdates().listen((p) {
        if (!mounted) return;
        setState(() => _best = Fix.better(_best, Fix(p)));
      }, onError: (Object e) => debugPrint('[sos] position updates: $e'));
    });
  }

  @override
  void dispose() {
    _updates?.cancel();
    _description.dispose();
    _landmark.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  // ---------- media ----------

  Future<void> _pickImage() async {
    // Smaller photos upload faster on mobile data (and stay under 5 MB).
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      imageQuality: 75,
    );
    if (file != null) setState(() => _image = file);
  }

  Future<void> _pickVideo() async {
    final file = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 20),
    );
    if (file == null) return;
    if (await file.length() > _maxVideoBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'That video is too large. Please record a shorter one.',
          ),
        ),
      );
      return;
    }

    final controller = VideoPlayerController.file(File(file.path));
    try {
      await controller.initialize();
    } catch (_) {
      await controller.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not load the video')));
      return;
    }

    final old = _videoCtrl;
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _video = file;
      _videoCtrl = controller;
    });
    await old?.dispose();
  }

  void _removeImage() => setState(() => _image = null);

  void _removeVideo() {
    final old = _videoCtrl;
    setState(() {
      _video = null;
      _videoCtrl = null;
    });
    old?.dispose();
  }

  // ---------- send ----------

  Future<void> _send() async {
    if (_landmark.text.trim().isEmpty ||
        _severity == null ||
        _injured == null) {
      setState(() => _showErrors = true);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Please add a landmark and answer both questions'),
          ),
        );
      return;
    }

    // Require a location fix before sending.
    if (!_hasLocationFix) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Waiting for your location... please wait a moment and try again.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      return;
    }

    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);

    // 1) The request itself: this is what alerts the admin.
    final fix = _best!;
    final result = await ResidentSos.instance.send(
      landmark: _landmark.text,
      severity: _severity!,
      injured: _injured!,
      description: _description.text,
      fix: fix,
    );
    if (!mounted) return;
    if (result.error != null) {
      setState(() => _sending = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 8),
            content: Text(
              'Your SOS was NOT sent: ${result.error}\n'
              'If this is life-threatening, call 911 now.',
            ),
            action: SnackBarAction(label: 'Try again', onPressed: _send),
          ),
        );
      return;
    }

    // 2) The photo / video. The SOS is already delivered if this fails.
    final mediaError = await ResidentSos.instance.uploadMedia(
      result.sos!.id,
      imagePath: _image?.path,
      videoPath: _video?.path,
    );

    if (!mounted) return;
    setState(() => _sending = false);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: Duration(seconds: mediaError == null ? 4 : 8),
          content: Text(
            mediaError == null
                ? 'Emergency request sent. The admin has been alerted.'
                : 'Emergency request sent and the admin has been alerted, '
                      'but the photo/video could not be uploaded: $mediaError',
          ),
        ),
      );
    Navigator.pop(context);
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pal.background,
      appBar: patientAppBar(context, 'SOS request'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  Sp.gutter,
                  Sp.sm,
                  Sp.gutter,
                  Sp.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tell us what happened', style: T.title),
                    const SizedBox(height: Sp.xs),
                    Text(
                      'The Go Bike admin sees this as soon as you send it.',
                      style: T.secondary.muted(context),
                    ),
                    const SizedBox(height: Sp.xl),
                    _sectionHeader('Where are you?'),
                    const SizedBox(height: Sp.xs),
                    Text(_barangayNote(), style: T.meta.muted(context)),
                    const SizedBox(height: Sp.md),
                    _locationStatusRow(),
                    const SizedBox(height: Sp.lg),
                    _fieldLabel('Landmark'),
                    TextField(
                      style: T.body.copyWith(color: context.pal.ink),
                      cursorColor: context.pal.brand,
                      controller: _landmark,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => _showErrors ? setState(() {}) : null,
                      decoration: _inputDecoration(
                        'e.g. Beside the barangay hall',
                        prefix: Icons.flag_outlined,
                        error: _requiredError(_landmark),
                      ),
                    ),
                    const SizedBox(height: Sp.xl),
                    _requiredHeader('How serious is it?'),
                    const SizedBox(height: Sp.md),
                    _severityChoices(),
                    const SizedBox(height: Sp.xl),
                    _requiredHeader('Are there injured people?'),
                    const SizedBox(height: Sp.md),
                    _injuredChoices(),
                    const SizedBox(height: Sp.xl),
                    _sectionHeader('What happened?'),
                    const SizedBox(height: Sp.md),
                    TextField(
                      style: T.body.copyWith(color: context.pal.ink),
                      cursorColor: context.pal.brand,
                      controller: _description,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDecoration(
                        'Briefly describe the emergency (optional)',
                      ),
                    ),
                    const SizedBox(height: Sp.lg),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _UploadTile(
                                icon: Icons.add_a_photo_outlined,
                                label: _image == null
                                    ? 'Add photo'
                                    : 'Change photo',
                                onTap: _pickImage,
                              ),
                              if (_image != null) ...[
                                const SizedBox(height: Sp.sm),
                                _PreviewBox(
                                  label: 'photo',
                                  onRemove: _removeImage,
                                  child: Image.file(
                                    File(_image!.path),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: Sp.md),
                        Expanded(
                          child: Column(
                            children: [
                              _UploadTile(
                                icon: Icons.videocam_outlined,
                                label: _video == null
                                    ? 'Add video'
                                    : 'Change video',
                                onTap: _pickVideo,
                              ),
                              if (_video != null && _videoCtrl != null) ...[
                                const SizedBox(height: Sp.sm),
                                _PreviewBox(
                                  label: 'video',
                                  onRemove: _removeVideo,
                                  child: _videoPreview(_videoCtrl!),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Sp.sm),
                    Center(
                      child: Text(
                        'A photo or video helps responders prepare.',
                        style: T.meta.muted(context),
                      ),
                    ),
                    const SizedBox(height: Sp.xl),
                    _warning(),
                  ],
                ),
              ),
            ),
            // The one main action, always in the same spot.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Sp.gutter,
                Sp.xs,
                Sp.gutter,
                Sp.lg,
              ),
              child: PrimaryButton(
                label: 'Send SOS',
                icon: Icons.send_rounded,
                danger: true,
                loading: _sending,
                enabled: _canSend,
                onPressed: _send,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _videoPreview(VideoPlayerController c) {
    return GestureDetector(
      onTap: () => c.value.isPlaying ? c.pause() : c.play(),
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: c,
        builder: (context, v, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: v.size.width,
                  height: v.size.height,
                  child: VideoPlayer(c),
                ),
              ),
              if (!v.isPlaying)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Shows location status and guides the user if there's a problem.
  Widget _locationStatusRow() {
    // A Material, not a decorated box: the row's ripple paints on the nearest Material.
    return Material(
      color: context.pal.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Rd.control),
        side: BorderSide(color: context.pal.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Sp.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _hasLocationFix
                      ? Icons.my_location_rounded
                      : Icons.gps_not_fixed_rounded,
                  color: _hasLocationFix
                      ? context.pal.greenText
                      : context.pal.orangeText,
                  size: 24,
                ),
                const SizedBox(width: Sp.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your location', style: T.rowTitle),
                      const SizedBox(height: 2),
                      Text(
                        _hasLocationFix
                            ? 'Responders will see a pin where you are.'
                            : 'Waiting for GPS... please wait a moment.',
                        style: T.secondary.muted(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_locationProblem != null) ...[
              const SizedBox(height: Sp.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: context.pal.orangeText,
                    ),
                  ),
                  const SizedBox(width: Sp.sm),
                  Expanded(
                    child: Text(
                      _locationProblem == LocationState.serviceOff
                          ? 'Location is off on this phone. Turn it on to share your location.'
                          : 'Go Bike is not allowed to use your location. Allow it in settings.',
                      style: T.secondary.muted(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Sp.sm),
              TextButton(
                onPressed: () =>
                    LocationGate.instance.openSettingsFor(_locationProblem!),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: context.pal.ink,
                ),
                child: const Text('Open settings'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The server files the SOS under the resident's own barangay.
  String _barangayNote() {
    final barangay = AuthService.instance.currentUser?.barangay;
    return (barangay == null || barangay.isEmpty)
        ? 'Set your barangay in your profile so we can find you.'
        : 'Barangay $barangay, Bugallon (from your profile)';
  }

  String? _requiredError(TextEditingController c) =>
      _showErrors && c.text.trim().isEmpty ? 'Required' : null;

  InputDecoration _inputDecoration(
    String hint, {
    IconData? prefix,
    String? error,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(Rd.control),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      errorText: error,
      errorBorder: border(context.pal.redText),
      focusedErrorBorder: border(context.pal.redText, 1.5),
      hintText: hint,
      hintStyle: T.body.copyWith(color: context.pal.muted),
      prefixIcon: prefix == null
          ? null
          : Icon(prefix, color: context.pal.muted, size: 22),
      filled: true,
      fillColor: context.pal.card,
      contentPadding: const EdgeInsets.all(Sp.lg),
      border: border(context.pal.line),
      enabledBorder: border(context.pal.line),
      focusedBorder: border(context.pal.brand, 1.5),
    );
  }

  /// Label for a required field, marked with a red asterisk.
  Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text.rich(
      TextSpan(
        text: text,
        style: T.label,
        children: [
          TextSpan(
            text: ' *',
            style: TextStyle(color: context.pal.redText),
          ),
        ],
      ),
      semanticsLabel: '$text, required',
    ),
  );

  Widget _sectionHeader(String title) => Text(title, style: T.heading);

  /// A section the resident must answer, marked like a required field.
  Widget _requiredHeader(String title) => Text.rich(
    TextSpan(
      text: title,
      style: T.heading,
      children: [
        TextSpan(
          text: ' *',
          style: TextStyle(color: context.pal.redText),
        ),
      ],
    ),
    semanticsLabel: '$title, required',
  );

  /// Four choices, mildest first, each in its color with a line saying what it means.
  Widget _severityChoices() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final c in kSosSeverities) ...[
        _ChoiceTile(
          label: c.label,
          hint: c.hint,
          color: severityColor(context, c.value)!,
          selected: _severity == c.value,
          onTap: () => setState(() => _severity = c.value),
        ),
        if (c != kSosSeverities.last) const SizedBox(height: Sp.sm),
      ],
      if (_showErrors && _severity == null) _choiceError(),
    ],
  );

  /// Yes / No / Not sure, one row of radio buttons.
  Widget _injuredChoices() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          for (final c in kSosInjured) ...[
            Expanded(
              child: _ChoiceTile(
                label: c.label,
                color: context.pal.brand,
                selected: _injured == c.value,
                onTap: () => setState(() => _injured = c.value),
              ),
            ),
            if (c != kSosInjured.last) const SizedBox(width: Sp.sm),
          ],
        ],
      ),
      if (_showErrors && _injured == null) _choiceError(),
    ],
  );

  Widget _choiceError() => Padding(
    padding: const EdgeInsets.only(top: 6, left: Sp.md),
    child: Text('Required', style: T.meta.copyWith(color: context.pal.redText)),
  );

  Widget _warning() {
    return Container(
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        color: context.pal.redSoft,
        borderRadius: BorderRadius.circular(Rd.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: context.pal.redText,
            size: 20,
          ),
          SizedBox(width: Sp.md),
          Expanded(
            child: Text(
              'False reports are punishable by law. Only use this for real '
              'emergencies that need immediate help.',
              style: T.secondary.muted(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Square preview with a remove (X) button in the corner.
class _PreviewBox extends StatelessWidget {
  final Widget child;
  final String label;
  final VoidCallback onRemove;

  const _PreviewBox({
    required this.child,
    required this.label,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Rd.control),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: Colors.black12, child: child),
            Positioned(
              top: 0,
              right: 0,
              child: Semantics(
                button: true,
                label: 'Remove $label',
                excludeSemantics: true,
                child: InkWell(
                  onTap: onRemove,
                  // A 48-dp target around the small icon.
                  child: const Padding(
                    padding: EdgeInsets.all(Sp.sm),
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close, size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _UploadTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: context.pal.card,
        borderRadius: BorderRadius.circular(Rd.control),
        child: InkWell(
          borderRadius: BorderRadius.circular(Rd.control),
          onTap: onTap,
          child: Container(
            height: 88,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Rd.control),
              border: Border.all(color: context.pal.line),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: context.pal.ink, size: 24),
                const SizedBox(height: Sp.sm),
                Text(label, style: T.label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One answer to pick: a radio mark, the label (and a hint line), outlined in [color]
/// once picked. Only one in a group is picked at a time.
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.hint = '',
  });

  final String label;
  final String hint;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: hint.isEmpty ? label : '$label. $hint',
      excludeSemantics: true,
      child: Material(
        color: selected ? color.withValues(alpha: 0.12) : context.pal.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Rd.control),
          side: BorderSide(
            color: selected ? color : context.pal.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Sp.md,
                vertical: Sp.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: selected ? color : context.pal.muted,
                    size: 22,
                  ),
                  const SizedBox(width: Sp.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: T.label.copyWith(
                            color: hint.isEmpty ? context.pal.ink : color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (hint.isNotEmpty)
                          Text(hint, style: T.meta.muted(context)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
