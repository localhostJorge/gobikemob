import 'package:flutter/material.dart';

import '../core/patient_service.dart';
import '../core/theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/confirm_modal.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/patient_form.dart';

class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key, this.barangay});

  /// The barangay of the current ronda (saved with the record).
  final String? barangay;

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final PatientFormControllers _c = PatientFormControllers();
  bool _saving = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      AppToast.show(
        context,
        'Please check the highlighted fields.',
        type: ToastType.error,
      );
      return;
    }

    final confirmed = await ConfirmModal.show(
      context: context,
      icon: Icons.person_add_alt_1_rounded,
      color: AppTheme.blue,
      title: 'Save this patient record?',
      description: "The record will be saved to the Go Bike patient log.",
      confirmText: 'Save',
      onConfirm: () {},
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    final result = await PatientService.instance.create(
      _c.toMap(),
      barangay: widget.barangay,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (!result.ok) {
      AppToast.show(context, result.error!, type: ToastType.error);
      return; // stay on the form so nothing typed is lost
    }
    Navigator.pop(context, result.data); // the saved record, with its server id
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _saving,
      message: 'Saving record...',
      child: Scaffold(
        backgroundColor: authBackground(context),
        appBar: AppBar(
          backgroundColor: authBackground(context),
          scrolledUnderElevation: 0,
          centerTitle: true,
          title: const Text(
            'New Patient',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PatientForm(controllers: _c),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: const Text(
                        'Save Patient',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
