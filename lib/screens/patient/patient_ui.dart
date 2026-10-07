import 'package:flutter/material.dart';
import 'app_colors.dart';

BoxDecoration cardDecoration([double radius = 16]) => BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );

PreferredSizeWidget patientAppBar(BuildContext context, String title) {
  return AppBar(
    backgroundColor: AppColors.background,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
      onPressed: () => Navigator.pop(context),
    ),
    title: Text(
      title,
      style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark),
    ),
  );
}

InputDecoration inputDecoration(String label, IconData icon, {Widget? suffix}) {
  OutlineInputBorder border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c),
      );
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: AppColors.textMuted),
    suffixIcon: suffix,
    filled: true,
    fillColor: Colors.white,
    border: border(Colors.grey.shade300),
    enabledBorder: border(Colors.grey.shade300),
    focusedBorder: border(AppColors.red),
    errorBorder: border(AppColors.red),
    focusedErrorBorder: border(AppColors.red),
  );
}

Widget primaryButton({
  required String label,
  required VoidCallback? onPressed,
  bool loading = false,
}) {
  return SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.red,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.red.withValues(alpha: 0.4),
        disabledForegroundColor: Colors.white70,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, letterSpacing: 0.3)),
    ),
  );
}