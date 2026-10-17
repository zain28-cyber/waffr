// Second signup step: email and password for a new account.

import 'package:flutter/material.dart';
import 'package:waffr/widgets/button/app_primary_button.dart';
import 'package:waffr/data/models/registration_profile.dart';
import 'package:waffr/core/sync/auth_session.dart';
import 'package:waffr/core/sync/sync_service.dart';
import 'package:waffr/core/utils/app_feedback.dart';
import 'package:waffr/screens/offline/login/auth_fields.dart';
import 'package:waffr/widgets/brand/waffr_page_header.dart';
import 'package:waffr/widgets/containers/glass.dart';
import 'package:waffr/core/theme/app_palette.dart';

/// Credential step of signup: email, password, confirm. Registers with the
/// [profile] collected on the user-info step.
class RegisterScreen extends StatefulWidget {
  /// Profile from the user-info step, sent with the registration.
  final RegistrationProfile profile;

  /// Runs after the account is created and synced.
  final Future<void> Function() onCompleted;

  /// Back action from the header; when null the route is popped.
  final VoidCallback? onBack;

  /// Also pop the login route after success.
  final bool popOnSuccess;

  /// Creates a [RegisterScreen].
  const RegisterScreen({
    super.key,
    required this.profile,
    required this.onCompleted,
    this.onBack,
    this.popOnSuccess = false,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

/// State of [RegisterScreen]. Owns the email, password and confirm
/// controllers.
class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  /// A request is running; fields and buttons are disabled.
  bool _busy = false;

  /// Shown above the main button; cleared as soon as a field changes.
  String? _message;
  AppFeedbackKind _messageKind = AppFeedbackKind.error;

  /// Hides both password fields.
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// Email looks valid, password has 8+ characters and matches the
  /// confirmation, and nothing is running.
  bool get _canSubmit {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    return email.contains('@') &&
        email.contains('.') &&
        password.length >= 8 &&
        password == _confirmController.text &&
        !_busy;
  }

  /// Registers, syncs, runs the completion, then pops the signup route (and
  /// the login route too when [RegisterScreen.popOnSuccess]).
  Future<void> _register() async {
    if (!_canSubmit) return;

    setState(() => _busy = true);

    final result = await AuthSession.instance.register(
      email: _emailController.text,
      password: _passwordController.text,
      profile: widget.profile,
    );

    if (!mounted) return;

    if (!result.ok) {
      setState(() => _busy = false);
      _show(result.message);
      return;
    }

    await SyncService.instance.syncNow();
    if (!mounted) return;

    final navigator = Navigator.of(context);
    final completed = widget.onCompleted;
    final popOnSuccess = widget.popOnSuccess;
    await completed();
    if (!navigator.mounted) return;
    if (navigator.canPop()) {
      navigator.pop();
    }
    if (popOnSuccess && navigator.canPop()) {
      navigator.pop();
    }
  }

  /// Prefer the flow's onBack (step 0) over popping the whole route.
  void _leaveCredentials() {
    if (_busy) return;
    final back = widget.onBack;
    if (back != null) {
      back();
      return;
    }
    Navigator.of(context).pop();
  }

  /// Shows [message] in the inline message slot.
  void _show(String? message, {bool success = false}) {
    setState(() {
      _message = message;
      _messageKind = success ? AppFeedbackKind.success : AppFeedbackKind.error;
    });
  }

  bool get _emailValid {
    final email = _emailController.text.trim();
    return email.contains('@') && email.contains('.');
  }

  /// Why the main button is disabled, in plain words.
  String? get _missingReason {
    final password = _passwordController.text;
    if (!_emailValid) return 'أدخل بريداً إلكترونياً صالحاً';
    if (password.length < 8) {
      return 'كلمة المرور يجب أن تتكون من 8 أحرف على الأقل';
    }
    if (password != _confirmController.text) {
      return 'كلمتا المرور غير متطابقتين';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final bg = palette.background;
    final surface = palette.surface;
    final textPrimary = palette.textPrimary;
    final textSecondary = palette.textSecondary;
    final accent = palette.accent;

    return Scaffold(
      backgroundColor: bg,
      appBar: WaffrBackHeader(
        enabled: !_busy,
        onBack: _leaveCredentials,
        title: 'إنشاء حساب',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'أنشئ حساباً لحفظ بياناتك ومزامنتها',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 28),
            // Email, password and confirmation card.
            GlassContainer(
              colorType: GlassColorType.surface,
              borderRadius: 28,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthFieldLabel(text: 'البريد الإلكتروني', color: textPrimary),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    autocorrect: false,
                    onChanged: (_) => setState(() => _message = null),
                    style: TextStyle(color: textPrimary, fontSize: 16),
                    decoration: authFieldDecoration(
                      hint: 'example@email.com',
                      fillColor: surface,
                      textSecondary: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AuthFieldLabel(text: 'كلمة المرور', color: textPrimary),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    enabled: !_busy,
                    obscureText: _obscure,
                    onChanged: (_) => setState(() => _message = null),
                    style: TextStyle(color: textPrimary, fontSize: 16),
                    decoration: authFieldDecoration(
                      hint: '8 أحرف على الأقل',
                      fillColor: surface,
                      textSecondary: textSecondary,
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AuthFieldLabel(text: 'تأكيد كلمة المرور', color: textPrimary),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _confirmController,
                    enabled: !_busy,
                    obscureText: _obscure,
                    onChanged: (_) => setState(() => _message = null),
                    style: TextStyle(color: textPrimary, fontSize: 16),
                    decoration: authFieldDecoration(
                      hint: 'أعد كتابة كلمة المرور',
                      fillColor: surface,
                      textSecondary: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            // Message, create button, and the back-to-login link.
            AppInlineMessage(message: _message, kind: _messageKind),
            AppPrimaryButton(
              label: 'إنشاء الحساب',
              enabled: _canSubmit,
              onDisabledTap: () => _show(_missingReason),
              busy: _busy,
              onTap: _register,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: Text(
                'لديك حساب؟ تسجيل الدخول',
                style: TextStyle(
                  color: accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Outfit',
                  fontFamilyFallback: ['Tajawal'],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
