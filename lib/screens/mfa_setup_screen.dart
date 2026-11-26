// Turning two-step login on: a key for the authenticator app, then the first
// code it shows, then the 10 backup codes, shown only this once. Pops true once
// it is on.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/auth_service.dart';
import '../widgets/app_toast.dart';
import '../widgets/mfa_widgets.dart';
import 'patient/app_colors.dart';
import 'patient/ui_kit.dart';

class MfaSetupScreen extends StatefulWidget {
  const MfaSetupScreen({super.key});

  @override
  State<MfaSetupScreen> createState() => _MfaSetupScreenState();
}

class _MfaSetupScreenState extends State<MfaSetupScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();

  bool _loading = true;
  String? _loadError;
  MfaSetupResult? _setup;

  bool _verifying = false;
  String? _codeError;

  /// Set once two-step login is on: the codes step shows.
  List<String>? _backupCodes;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final result = await AuthService.instance.mfaSetup();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.ok) {
        _setup = result;
      } else {
        _loadError = result.message ?? 'Could not start two-step login.';
      }
    });
  }

  Future<void> _copyKey() async {
    final secret = _setup?.secret;
    if (secret == null) return;
    await Clipboard.setData(ClipboardData(text: secret));
    if (!mounted) return;
    AppToast.show(context, 'Setup key copied.', type: ToastType.success);
  }

  Future<void> _openApp() async {
    final url = _setup?.otpauthUrl;
    if (url == null) return;
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (opened || !mounted) return;
    AppToast.show(
      context,
      'No authenticator app found. Copy the key into one instead.',
      type: ToastType.error,
    );
  }

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    if (_verifying || !_form.currentState!.validate()) return;
    setState(() {
      _verifying = true;
      _codeError = null;
    });
    final result = await AuthService.instance.mfaEnable(_code.text);
    if (!mounted) return;
    setState(() {
      _verifying = false;
      if (result.ok) {
        _backupCodes = result.backupCodes;
      } else {
        _codeError = result.message ?? 'That code is wrong. Try again.';
      }
    });
  }

  void _done() {
    AppToast.show(context, 'Two-step login is on.', type: ToastType.success);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final codes = _backupCodes;
    return PopScope(
      // The codes are shown only once: leave with "I saved them".
      canPop: codes == null,
      child: Scaffold(
        backgroundColor: context.pal.background,
        appBar: codes == null
            ? rondaAppBar(context, 'Two-step login')
            : AppBar(
                backgroundColor: context.pal.background,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                automaticallyImplyLeading: false,
                title: Text(
                  'Save your backup codes',
                  style: T.heading.copyWith(color: context.pal.heading),
                ),
              ),
        body: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: _body(context, codes),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, List<String>? codes) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = _loadError;
    if (error != null) {
      return ListView(
        padding: const EdgeInsets.all(Sp.gutter),
        children: [InlineNotice(message: error, onAction: _start)],
      );
    }
    if (codes != null) return _codesStep(context, codes);
    return _keyStep(context);
  }

  Widget _keyStep(BuildContext context) {
    final setup = _setup!;
    final pal = context.pal;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(Sp.gutter),
      children: [
        Text(
          'After your password, the app will also ask for a code from an '
          'authenticator app on your phone, such as Google Authenticator or '
          'Microsoft Authenticator.',
          style: T.body.muted(context),
        ),
        const SizedBox(height: Sp.xl),
        const SectionHeader('1. Add Go Bike to your authenticator app'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Setup key', style: T.label.muted(context)),
              const SizedBox(height: Sp.xs),
              SelectableText(
                setup.secret!,
                style: T.body.copyWith(
                  color: pal.ink,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: Sp.md),
              SecondaryButton(
                label: 'Copy key',
                icon: Icons.copy_rounded,
                onPressed: _copyKey,
              ),
              if (setup.otpauthUrl != null) ...[
                const SizedBox(height: Sp.sm),
                PrimaryButton(
                  label: 'Open in authenticator app',
                  icon: Icons.open_in_new_rounded,
                  onPressed: _openApp,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: Sp.xl),
        const SectionHeader('2. Enter the code it shows'),
        Form(
          key: _form,
          child: MfaCodeField(controller: _code, onSubmitted: (_) => _verify()),
        ),
        MfaError(_codeError),
        const SizedBox(height: Sp.lg),
        PrimaryButton(
          label: 'Turn on',
          loading: _verifying,
          onPressed: _verifying ? null : _verify,
        ),
      ],
    );
  }

  Widget _codesStep(BuildContext context, List<String> codes) => ListView(
    padding: const EdgeInsets.all(Sp.gutter),
    children: [
      Text(
        'Two-step login is on. If you lose your phone, each of these codes '
        'lets you sign in once. Keep them somewhere safe: they are shown '
        'only now.',
        style: T.body.muted(context),
      ),
      const SizedBox(height: Sp.lg),
      BackupCodesList(codes: codes),
      const SizedBox(height: Sp.lg),
      PrimaryButton(label: 'I saved them', onPressed: _done),
    ],
  );
}
