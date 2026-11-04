import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

import 'app_toast.dart';

/// Lets the person frame their profile photo before it is used: drag and pinch the picture
/// under a circular guide, then Apply. Pops with the cropped picture (a square, so it fits
/// every circle and thumbnail it is shown in), or null when they cancel.
///
/// Dark on purpose, in light and dark mode alike: a photo is judged best against a neutral
/// dark surround, and the shade outside the circle has to read as "this part is cut off".
class PhotoCropScreen extends StatefulWidget {
  const PhotoCropScreen({super.key, required this.image});

  /// The picture the person chose or took.
  final Uint8List image;

  @override
  State<PhotoCropScreen> createState() => _PhotoCropScreenState();
}

class _PhotoCropScreenState extends State<PhotoCropScreen> {
  static const _backdrop = Color(0xFF0B0C10);
  static const _brandBlue = Color(0xFF2E62C8);

  final _controller = CropController();

  /// The picture has loaded and can be framed.
  bool _ready = false;

  /// The crop is being made: nothing else can be pressed until it is.
  bool _cropping = false;

  void _onStatus(CropStatus status) {
    if (!mounted) return;
    setState(() {
      _ready = status == CropStatus.ready || status == CropStatus.cropping;
      _cropping = status == CropStatus.cropping;
    });
  }

  void _onCropped(CropResult result) {
    if (!mounted) return;
    switch (result) {
      case CropSuccess(:final croppedImage):
        Navigator.of(context).pop(croppedImage);
      case CropFailure():
        setState(() => _cropping = false);
        AppToast.show(
          context,
          "Couldn't crop this photo. Try another one.",
          type: ToastType.error,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canApply = _ready && !_cropping;

    return Scaffold(
      backgroundColor: _backdrop,
      appBar: AppBar(
        backgroundColor: _backdrop,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Cancel',
          icon: const Icon(Icons.close_rounded),
          onPressed: _cropping ? null : () => Navigator.of(context).pop(),
        ),
        title: const Text('Crop photo'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Semantics(
                label:
                    'Photo crop area. Drag to move the photo, pinch to zoom.',
                child: Crop(
                  image: widget.image,
                  controller: _controller,
                  // The circle is what the photo will look like; the saved picture is the
                  // square around it.
                  withCircleUi: true,
                  aspectRatio: 1,
                  baseColor: _backdrop,
                  maskColor: Colors.black.withValues(alpha: 0.62),
                  onStatusChanged: _onStatus,
                  onCropped: _onCropped,
                  progressIndicator: const CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 4),
              child: Text(
                'Drag and pinch to fit your face inside the circle.',
                textAlign: TextAlign.center,
                // 0xFFC9CCD6 on the backdrop is about 11:1, well above 4.5:1.
                style: TextStyle(color: Color(0xFFC9CCD6), fontSize: 14),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cropping
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white38,
                        side: const BorderSide(color: Colors.white38),
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: canApply ? _controller.crop : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: _brandBlue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _brandBlue.withValues(
                          alpha: 0.4,
                        ),
                        disabledForegroundColor: Colors.white70,
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: _cropping
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
