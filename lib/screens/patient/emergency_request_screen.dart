import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../core/auth_service.dart';
import '../../core/resident_sos.dart';

import 'app_colors.dart';
import 'ui_kit.dart';

/// Municipality -> list of barangays.
/// To support another municipality later, just add another entry here.
const Map<String, List<String>> kLocations = {
  'Bugallon': [
    'Angarian',
    'Asinan',
    'Bañaga',
    'Bacabac',
    'Bolaoen',
    'Buenlag',
    'Cabayaoasan',
    'Cayanga',
    'Gueset',
    'Hacienda',
    'Laguit Centro',
    'Laguit Padilla',
    'Magtaking',
    'Pangascasan',
    'Pantal',
    'Poblacion',
    'Polong',
    'Portic',
    'Salasa',
    'Salomague Norte',
    'Salomague Sur',
    'Samat',
    'San Francisco',
    'Umanday',
  ],
};

class EmergencyRequestScreen extends StatefulWidget {
  const EmergencyRequestScreen({super.key});

  @override
  State<EmergencyRequestScreen> createState() => _EmergencyRequestScreenState();
}

class _EmergencyRequestScreenState extends State<EmergencyRequestScreen> {
  final _description = TextEditingController();
  final _landmark = TextEditingController();
  final _picker = ImagePicker();

  String? _municipality;
  String? _barangay;

  XFile? _image;
  XFile? _video;
  VideoPlayerController? _videoCtrl;
  bool _sending = false;

  /// Started when the screen opens, so the position is usually ready on Send.
  late final Future<Position?> _position = ResidentSos.quickPosition();

  // The server accepts videos up to 50 MB.
  static const int _maxVideoBytes = 50 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    _position; // start looking for the phone's position now
    // Most emergencies are at home: start from the resident's own barangay.
    final home = AuthService.instance.currentUser?.barangay;
    for (final entry in kLocations.entries) {
      if (entry.value.contains(home)) {
        _municipality = entry.key;
        _barangay = home;
        break;
      }
    }
  }

  @override
  void dispose() {
    _description.dispose();
    _landmark.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  // ---------- location pickers ----------

  Future<void> _chooseMunicipality() async {
    final result = await _showOptions(
      title: 'Select Municipality',
      options: kLocations.keys.toList(),
      selected: _municipality,
    );
    if (result == null || result == _municipality) return;
    setState(() {
      _municipality = result;
      _barangay = null; // barangay depends on municipality
      _landmark.clear();
    });
  }

  Future<void> _chooseBarangay() async {
    final result = await _showOptions(
      title: 'Select Barangay',
      options: kLocations[_municipality] ?? const [],
      selected: _barangay,
      searchable: true,
    );
    if (result != null) setState(() => _barangay = result);
  }

  Future<String?> _showOptions({
    required String title,
    required List<String> options,
    String? selected,
    bool searchable = false,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Rd.sheet)),
      ),
      builder: (_) => _OptionSheet(
        title: title,
        options: options,
        selected: selected,
        searchable: searchable,
      ),
    );
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
    if (_municipality == null ||
        _barangay == null ||
        _landmark.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Please select municipality, barangay and landmark'),
          ),
        );
      return;
    }

    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);

    // 1) The request itself: this is what alerts the admin.
    final position = await _position.timeout(
      const Duration(seconds: 3),
      onTimeout: () => null,
    );
    final result = await ResidentSos.instance.send(
      municipality: _municipality!,
      barangay: _barangay!,
      landmark: _landmark.text,
      description: _description.text,
      position: position,
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
      backgroundColor: AppColors.background,
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
                    const Text(
                      'The Go Bike admin sees this as soon as you send it.',
                      style: T.secondary,
                    ),
                    const SizedBox(height: Sp.xl),
                    _sectionHeader('Where are you?'),
                    const SizedBox(height: Sp.md),
                    _fieldLabel('Municipality'),
                    _PickerField(
                      value: _municipality,
                      hint: 'Select municipality',
                      icon: Icons.location_city_outlined,
                      onTap: _chooseMunicipality,
                    ),
                    if (_municipality != null) ...[
                      const SizedBox(height: Sp.lg),
                      _fieldLabel('Barangay'),
                      _PickerField(
                        value: _barangay,
                        hint: 'Select barangay',
                        icon: Icons.map_outlined,
                        onTap: _chooseBarangay,
                      ),
                    ],
                    if (_barangay != null) ...[
                      const SizedBox(height: Sp.lg),
                      _fieldLabel('Landmark'),
                      TextField(
                        controller: _landmark,
                        textCapitalization: TextCapitalization.words,
                        decoration: _inputDecoration(
                          'e.g. Beside the barangay hall',
                          prefix: Icons.flag_outlined,
                        ),
                      ),
                    ],
                    const SizedBox(height: Sp.xl),
                    _sectionHeader('What happened?'),
                    const SizedBox(height: Sp.md),
                    TextField(
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
                    const Center(
                      child: Text(
                        'A photo or video helps responders prepare.',
                        style: T.meta,
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
                loading: _sending,
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

  InputDecoration _inputDecoration(String hint, {IconData? prefix}) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(Rd.control),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: T.body.copyWith(color: AppColors.textMuted),
      prefixIcon: prefix == null
          ? null
          : Icon(prefix, color: AppColors.textMuted, size: 22),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.all(Sp.lg),
      border: border(AppColors.line),
      enabledBorder: border(AppColors.line),
      focusedBorder: border(AppColors.textDark, 1.5),
    );
  }

  Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: T.label),
  );

  Widget _sectionHeader(String title) => Text(title, style: T.heading);

  Widget _warning() {
    return Container(
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        color: AppColors.redSoft,
        borderRadius: BorderRadius.circular(Rd.control),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.redText, size: 20),
          SizedBox(width: Sp.md),
          Expanded(
            child: Text(
              'False reports are punishable by law. Only use this for real '
              'emergencies that need immediate help.',
              style: T.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tappable field that looks like a dropdown and opens a bottom sheet.
class _PickerField extends StatelessWidget {
  final String? value;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;

  const _PickerField({
    required this.value,
    required this.hint,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return Semantics(
      button: true,
      label: hasValue ? '$hint: $value' : hint,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Rd.control),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(Rd.control),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textMuted, size: 22),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Text(
                  value ?? hint,
                  style: hasValue
                      ? T.body.copyWith(fontWeight: FontWeight.w600)
                      : T.body.copyWith(color: AppColors.textMuted),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet list with an optional search bar at the top.
class _OptionSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  final String? selected;
  final bool searchable;

  const _OptionSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.searchable,
  });

  @override
  State<_OptionSheet> createState() => _OptionSheetState();
}

class _OptionSheetState extends State<_OptionSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = (media.size.height * 0.8 - media.viewInsets.bottom).clamp(
      240.0,
      700.0,
    );

    final filtered = widget.options
        .where((o) => o.toLowerCase().contains(_query.trim().toLowerCase()))
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(widget.title, style: T.heading),
              ),
            ),
            if (widget.searchable)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  autofocus: false,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search barangay',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Rd.control),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            Flexible(
              child: filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No results found', style: T.secondary),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final item = filtered[i];
                        final isSelected = item == widget.selected;
                        return ListTile(
                          title: Text(
                            item,
                            style: T.body.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: AppColors.textDark,
                                )
                              : null,
                          onTap: () => Navigator.pop(context, item),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
          ],
        ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(Rd.control),
        child: InkWell(
          borderRadius: BorderRadius.circular(Rd.control),
          onTap: onTap,
          child: Container(
            height: 88,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Rd.control),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: AppColors.textDark, size: 24),
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
