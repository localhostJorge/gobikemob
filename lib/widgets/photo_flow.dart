import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'photo_crop_screen.dart';

/// Takes or picks a picture. Replaced in tests.
typedef PhotoPicker = Future<XFile?> Function(ImageSource source);

/// Shows the crop screen for [image] and returns the cropped picture, or null if cancelled.
/// Replaced in tests.
typedef PhotoCropper = Future<Uint8List?> Function(
  BuildContext context,
  Uint8List image,
);

/// Big enough to crop well and show sharp, small enough to upload on mobile data.
Future<XFile?> _pickFromPhone(ImageSource source) => ImagePicker().pickImage(
  source: source,
  maxWidth: 1000,
  maxHeight: 1000,
  imageQuality: 85,
);

Future<Uint8List?> _cropOnScreen(BuildContext context, Uint8List image) =>
    Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PhotoCropScreen(image: image),
      ),
    );

/// The one way a profile photo is chosen, for residents and GoBikers, at sign-up and later:
/// pick (camera or gallery), crop, and only then is there a file to use. Returns the path of
/// the cropped picture, or null if they backed out at either step. Whatever the phone's
/// camera or gallery throws (no permission, no camera) is left for the caller to report.
///
/// Nothing uses a picked photo without going through here, so the crop step cannot be skipped.
Future<String?> pickProfilePhoto(
  BuildContext context,
  ImageSource source, {
  PhotoPicker pick = _pickFromPhone,
  PhotoCropper crop = _cropOnScreen,
  Future<Directory> Function()? tempDir,
}) async {
  final picked = await pick(source);
  if (picked == null || !context.mounted) return null;

  final original = await picked.readAsBytes();
  if (!context.mounted) return null;

  final cropped = await crop(context, original);
  if (cropped == null) return null;

  final dir = await (tempDir ?? getTemporaryDirectory)();
  // A new name every time, so a cached picture is never shown in place of the new one.
  final extension = picked.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
  final file = File(
    '${dir.path}/profile_${DateTime.now().microsecondsSinceEpoch}.$extension',
  );
  await file.writeAsBytes(cropped, flush: true);
  return file.path;
}
