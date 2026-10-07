import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'app_colors.dart';
import 'patient_store.dart';

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
            color: Colors.white,
            border: Border.all(color: AppColors.red, width: big ? 3 : 2),
          ),
          child: CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.redSoft,
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
                    color: const Color(0xFF3A3B3C),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.photo_camera,
                      size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
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
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(ctx, 'camera'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(ctx, 'gallery'),
          ),
          if (store.photoPath != null)
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: AppColors.red),
              title: const Text('Remove photo',
                  style: TextStyle(color: AppColors.red)),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          const SizedBox(height: 8),
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