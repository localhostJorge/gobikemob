import 'dart:io';
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import 'app_colors.dart';

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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
    final file = await _picker.pickImage(source: ImageSource.camera);
    if (file != null) setState(() => _image = file);
  }

  Future<void> _pickVideo() async {
    final file = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 30),
    );
    if (file == null) return;

    final controller = VideoPlayerController.file(File(file.path));
    try {
      await controller.initialize();
    } catch (_) {
      await controller.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load the video')),
      );
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
        ..showSnackBar(const SnackBar(
          content: Text('Please select municipality, barangay and landmark'),
        ));
      return;
    }

    setState(() => _sending = true);

    // TODO: upload media + send request to your backend with:
    // user id, timestamp, _municipality, _barangay, _landmark.text,
    // _description.text, _image?.path, _video?.path
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Emergency request sent')),
    );
    Navigator.pop(context);
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.red),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Request Details',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _titleRow(),
                    const SizedBox(height: 22),
                    _sectionHeader('Incident Location'),
                    const SizedBox(height: 12),
                    _fieldLabel('Municipality'),
                    _PickerField(
                      value: _municipality,
                      hint: 'Select municipality',
                      icon: Icons.location_city_outlined,
                      onTap: _chooseMunicipality,
                    ),
                    if (_municipality != null) ...[
                      const SizedBox(height: 14),
                      _fieldLabel('Barangay'),
                      _PickerField(
                        value: _barangay,
                        hint: 'Select barangay',
                        icon: Icons.map_outlined,
                        onTap: _chooseBarangay,
                      ),
                    ],
                    if (_barangay != null) ...[
                      const SizedBox(height: 14),
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
                    const SizedBox(height: 22),
                    _sectionHeader('Incident Description'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _description,
                      maxLines: 4,
                      decoration:
                          _inputDecoration('Briefly describe the emergency...'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _UploadTile(
                                icon: Icons.add_a_photo_outlined,
                                label: _image == null
                                    ? 'UPLOAD IMAGE'
                                    : 'CHANGE IMAGE',
                                onTap: _pickImage,
                              ),
                              if (_image != null) ...[
                                const SizedBox(height: 10),
                                _PreviewBox(
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            children: [
                              _UploadTile(
                                icon: Icons.videocam_outlined,
                                label: _video == null
                                    ? 'UPLOAD VIDEO'
                                    : 'CHANGE VIDEO',
                                onTap: _pickVideo,
                              ),
                              if (_video != null && _videoCtrl != null) ...[
                                const SizedBox(height: 10),
                                _PreviewBox(
                                  onRemove: _removeVideo,
                                  child: _videoPreview(_videoCtrl!),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Visual information helps responders prepare better.',
                        style: TextStyle(
                            fontSize: 11.5, color: AppColors.textMuted),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _warning(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _sending ? null : _send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.red,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.red.withValues(alpha: 0.5),
                    elevation: 4,
                    shadowColor: AppColors.red.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_outlined, size: 18),
                  label: Text(
                    _sending ? 'SENDING...' : 'SEND EMERGENCY REQUEST',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, letterSpacing: 0.5),
                  ),
                ),
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
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 30),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, {IconData? prefix}) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black38),
      prefixIcon:
          prefix == null ? null : Icon(prefix, color: AppColors.textMuted),
      filled: true,
      fillColor: Colors.white,
      border: border(Colors.grey.shade300),
      enabledBorder: border(Colors.grey.shade300),
      focusedBorder: border(AppColors.red),
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted)),
      );

  Widget _titleRow() {
    return Row(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: AppColors.redSoft,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.red.withValues(alpha: 0.25)),
          ),
          child: const Icon(Icons.medical_services_outlined,
              color: AppColors.red, size: 32),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Emergency Request',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark)),
              SizedBox(height: 2),
              Text('REQUEST IMMEDIATE ASSISTANCE',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: AppColors.red)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark));
  }

  Widget _warning() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.redSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.25)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.red, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'False reports are punishable by law. Only use this service '
              'for actual emergencies requiring immediate assistance.',
              style: TextStyle(fontSize: 12, color: Color(0xFF9B1C1C)),
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
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textMuted, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value ?? hint,
                style: TextStyle(
                  fontSize: 15,
                  color: hasValue ? AppColors.textDark : Colors.black38,
                  fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.textMuted),
          ],
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
    final maxHeight =
        (media.size.height * 0.8 - media.viewInsets.bottom).clamp(240.0, 700.0);

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
                child: Text(widget.title,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark)),
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
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            Flexible(
              child: filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No results found',
                          style: TextStyle(color: AppColors.textMuted)),
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
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.red
                                  : AppColors.textDark,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_rounded,
                                  color: AppColors.red)
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
  final VoidCallback onRemove;

  const _PreviewBox({required this.child, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: Colors.black12, child: child),
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
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
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter:
            _DashedRRectPainter(color: AppColors.red.withValues(alpha: 0.6)),
        child: Container(
          height: 96,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.redSoft.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.red, size: 26),
              const SizedBox(height: 8),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.red)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  const _DashedRRectPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(14)));
    for (final PathMetric m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 6), paint);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) => old.color != color;
}