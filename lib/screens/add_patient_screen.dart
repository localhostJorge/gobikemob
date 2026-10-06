import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/confirm_modal.dart';
import '../widgets/patient_form.dart';

class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final PatientFormControllers _c = PatientFormControllers();

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
      description: "The record will be added to today's patient log.",
      confirmText: 'Save',
      onConfirm: () {},
    );
    if (confirmed != true || !mounted) return;

    final Map<String, dynamic> data = _c.toMap();
    data['time'] = DateFormat('hh:mm a').format(DateTime.now());
    Navigator.pop(context, data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    onPressed: _submit,
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
    );
  }
}
