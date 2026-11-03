import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'app_colors.dart';
import 'patient_store.dart';
import 'ui_kit.dart';

/// Circular profile picture. Shows the patient's photo if they added one,
/// otherwise a person icon. With [showCamera] a small camera badge appears
/// at the bottom-right corner.
class ProfileAvatar extends StatelessWidget {
  final double radius;
  final bool showCamera;
  final VoidCallback? onCameraTap;

  const ProfileAvatar({
    super.key,
    this.radius = 40,
    this.showCamera = false,
    this.onCameraTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PatientStore.instance,
      builder: (context, _) {
        final path = PatientStore.instance.photoPath;
        final big = radius > 30;

        final avatar = Container(
          padding: EdgeInsets.all(big ? 4 : 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.pal.card,
            border: Border.all(color: AppColors.red, width: big ? 3 : 2),
          ),
          child: CircleAvatar(
            radius: radius,
            backgroundColor: context.pal.redSoft,
            backgroundImage: path == null ? null : FileImage(File(path)),
            child: path == null
                ? Icon(Icons.person, size: radius * 1.1, color: AppColors.red)
                : null,
          ),
        );

        if (!showCamera) return avatar;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            avatar,
            Positioned(
              right: 0,
              bottom: 2,
              child: GestureDetector(
                onTap: onCameraTap,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: context.pal.ink,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.pal.card, width: 2),
                  ),
                  child: Icon(
                    Icons.photo_camera,
                    size: 16,
                    color: context.pal.card,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The Profile item's icon in the bottom bar: the person's own photo as a small
/// circle (a person glyph until they add one). A ring marks it as the current tab,
/// as well as the red label, so the selection never depends on color alone.
class NavProfileIcon extends StatelessWidget {
  const NavProfileIcon({super.key, required this.selected});

  final bool selected;

  /// 24 dp photo plus the ring and the gap inside it: the same footprint as the
  /// 24 dp icons beside it, so the four labels stay on one line.
  static const double _photo = 20;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PatientStore.instance,
      builder: (context, _) {
        final path = PatientStore.instance.photoPath;
        return Container(
          width: 26,
          height: 26,
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? AppColors.red : context.pal.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: CircleAvatar(
            radius: _photo / 2,
            backgroundColor: context.pal.redSoft,
            backgroundImage: path == null ? null : FileImage(File(path)),
            child: path == null
                ? Icon(Icons.person, size: 14, color: AppColors.red)
                : null,
          ),
        );
      },
    );
  }
}

/// Bottom sheet: take a photo, choose from gallery, or remove the photo.
Future<void> changeProfilePhoto(BuildContext context) async {
  final store = PatientStore.instance;

  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: context.pal.card,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Rd.sheet)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo', style: T.body),
            onTap: () => Navigator.pop(ctx, 'camera'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery', style: T.body),
            onTap: () => Navigator.pop(ctx, 'gallery'),
          ),
          if (store.photoPath != null)
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: context.pal.redText,
              ),
              title: Text(
                'Remove photo',
                style: T.body.copyWith(color: context.pal.redText),
              ),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          const SizedBox(height: Sp.sm),
        ],
      ),
    ),
  );

  if (choice == null) return;
  if (choice == 'remove') {
    await store.removePhoto();
    return;
  }

  final file = await ImagePicker().pickImage(
    source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 800,
    imageQuality: 85,
  );
  if (file != null) await store.setPhoto(file.path);
}
