import 'package:flutter/material.dart';

import '../core/patient_service.dart';
import '../core/theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/confirm_modal.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/patient_form.dart';

class ViewPatientScreen extends StatefulWidget {
  final Map<String, dynamic> patient;
  const ViewPatientScreen({super.key, required this.patient});

  @override
  State<ViewPatientScreen> createState() => _ViewPatientScreenState();
}

class _ViewPatientScreenState extends State<ViewPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  late final PatientFormControllers _c = PatientFormControllers(widget.patient);
  bool _editing = false;
  bool _busy = false;
  String _busyMessage = 'Saving...';

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _cancelEdit() {
    FocusScope.of(context).unfocus();
    _c.fill(widget.patient); // discard changes
    setState(() => _editing = false);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      AppToast.show(
        context,
        'Please check the highlighted fields.',
        type: ToastType.error,
      );
      return;
    }

    final Map<String, dynamic> form = _c.toMap();
    form['barangay'] = widget.patient['barangay'];

    setState(() {
      _busy = true;
      _busyMessage = 'Saving changes...';
    });
    final result = await PatientService.instance.update(
      widget.patient['id'].toString(),
      form,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.ok) {
      AppToast.show(context, result.error!, type: ToastType.error);
      return; // stay in edit mode so nothing is lost
    }
    Navigator.pop(context, {'action': 'update', 'data': result.data});
  }

  Future<void> _confirmDelete() async {
    final confirmed = await ConfirmModal.show(
      context: context,
      icon: Icons.delete_outline_rounded,
      color: AppTheme.errorRed,
      title: 'Delete this record?',
      description: 'This will permanently delete the patient record. This cannot be undone.',
      confirmText: 'Delete',
      onConfirm: () {},
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _busyMessage = 'Deleting record...';
    });
    final error = await PatientService.instance.delete(
      widget.patient['id'].toString(),
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (error != null) {
      AppToast.show(context, error, type: ToastType.error);
      return;
    }
    Navigator.pop(context, {'action': 'delete', 'data': widget.patient});
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface
        .withValues(alpha: 0.6);
    final date = widget.patient['date']?.toString() ?? '';
    final time = widget.patient['time']?.toString() ?? '';

    return LoadingOverlay(
      isLoading: _busy,
      message: _busyMessage,
      child: Scaffold(
        backgroundColor: authBackground(context),
        appBar: AppBar(
          backgroundColor: authBackground(context),
          scrolledUnderElevation: 0,
          centerTitle: true,
          title: Text(
            _editing ? 'Edit Record' : 'Patient Record',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              tooltip: 'Delete record',
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppTheme.errorRed,
              ),
              onPressed: _busy ? null : _confirmDelete,
            ),
          ],
        ),
        body: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        children: [
                          Icon(
                            Icons.event_note_rounded,
                            size: 16,
                            color: muted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Recorded $date • $time',
                            style: TextStyle(fontSize: 13, color: muted),
                          ),
                        ],
                      ),
                    ),
                    PatientForm(controllers: _c, readOnly: !_editing),
                    const SizedBox(height: 32),
                    if (!_editing)
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _editing = true),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text(
                          'Edit Record',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _busy ? null : _cancelEdit,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _busy ? null : _save,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                              ),
                              child: const Text(
                                'Save Changes',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
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
