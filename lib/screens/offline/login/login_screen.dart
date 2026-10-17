// Login screen: email/password sign-in, links to registration and password
// reset, and the guest option.

import 'package:flutter/material.dart';
import 'package:waffr/widgets/button/app_primary_button.dart';
import 'package:waffr/data/services/backup_service.dart';
import 'package:waffr/core/sync/auth_session.dart';
import 'package:waffr/core/sync/sync_service.dart';
import 'package:waffr/core/utils/app_feedback.dart';
import 'package:waffr/screens/offline/login/account_creation_flow.dart';
import 'package:waffr/screens/offline/login/auth_fields.dart';
import 'package:waffr/screens/offline/login/forgot_password_screen.dart';
import 'package:waffr/widgets/brand/waffr_logo.dart';
import 'package:waffr/widgets/containers/glass.dart';
import 'package:waffr/core/prefs/app_prefs.dart';
import 'package:waffr/core/theme/app_palette.dart';

/// Sign-in with email/password, register, or continue as a local guest.
/// Used as the first gate in `main.dart` and pushed again from Settings and
/// the online tab.
class LoginScreen extends StatefulWidget {
  /// Runs after sign-in, registration, or choosing guest mode.
  final Future<void> Function() onCompleted;

  /// Shows the "continue as guest" action.
  final bool allowGuest;

  /// Pops this route after success (when it was pushed, not the gate).
  final bool popOnSuccess;

  /// Creates a [LoginScreen].
  const LoginScreen({
    super.key,
    required this.onCompleted,
    this.allowGuest = true,
    this.popOnSuccess = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// State of [LoginScreen]. Owns the email and password controllers.
class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  /// A request is running; fields and buttons are disabled.
  bool _busy = false;

  /// Shown above the main button; cleared as soon as a field changes.
  String? _message;
  AppFeedbackKind _messageKind = AppFeedbackKind.error;

  /// Hides the password text.
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Email looks valid, password is non-empty, and nothing is running.
  bool get _canSubmit {
    final email = _emailController.text.trim();
    return email.contains('@') &&
        email.contains('.') &&
        _passwordController.text.isNotEmpty &&
        !_busy;
  }

  /// Auth, sync, then clear first-launch so theme select is not shown again.
  Future<void> _login() async {
    if (!_canSubmit) return;

    setState(() => _busy = true);

    final result = await AuthSession.instance.login(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (!result.ok) {
      setState(() => _busy = false);
      _show(result.message);
      return;
    }

    await SyncService.instance.syncNow();
    if (!mounted) return;
    final prefs = await AppPrefs.instance;
    if (prefs.getBool('first_launch') ?? true) {
      await prefs.setBool('first_launch', false);
    }
    if (!mounted) return;
    await _finish();
  }

  /// Records the guest choice via [BackupService], then finishes.
  Future<void> _continueAsGuest() async {
    if (_busy) return;

    setState(() => _busy = true);
    await BackupService.instance.continueAsGuest();
    if (!mounted) return;
    await _finish();
  }

  /// Pushes the two-step [AccountCreationFlow].
  Future<void> _openRegister() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AccountCreationFlow(
          onCompleted: widget.onCompleted,
          popOnSuccess: widget.popOnSuccess,
        ),
      ),
    );
  }

  /// After a reset, sign in with the new password straight away.
  Future<void> _openForgotPassword() async {
    final result = await Navigator.of(context)
        .push<({String email, String password})>(
          MaterialPageRoute(
            builder: (_) => ForgotPasswordScreen(
              initialEmail: _emailController.text.trim(),
            ),
          ),
        );
    if (result == null || !mounted) return;
    _emailController.text = result.email;
    _passwordController.text = result.password;
    setState(() {});
    await _login();
  }

  /// Runs the caller's completion, then pops when [LoginScreen.popOnSuccess].
  Future<void> _finish() async {
    await widget.onCompleted();
    if (widget.popOnSuccess && mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
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
    if (!_emailValid) return 'أدخل بريداً إلكترونياً صالحاً';
    if (_passwordController.text.isEmpty) return 'أدخل كلمة المرور';
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo, welcome title and subtitle.
              const SizedBox(height: 20),
              const Center(child: WaffrLogo(size: 72)),
              const SizedBox(height: 16),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'مرحباً بك في '),
                    TextSpan(
                      text: 'وفّر',
                      style: TextStyle(color: accent),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                  fontFamilyFallback: ['Tajawal'],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'سجّل الدخول لمزامنة بياناتك بين أجهزتك',
                textAlign: TextAlign.center,
                style: TextStyle(color: textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 32),
              // Email and password card.
              GlassContainer(
                colorType: GlassColorType.surface,
                borderRadius: 28,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthFieldLabel(
                      text: 'البريد الإلكتروني',
                      color: textPrimary,
                    ),
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
                        hint: '••••••••',
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
                  ],
                ),
              ),
              // Forgot-password link, message, then the main action.
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: _busy ? null : _openForgotPassword,
                  child: Text(
                    'نسيت كلمة المرور؟',
                    style: TextStyle(
                      color: accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Outfit',
                      fontFamilyFallback: ['Tajawal'],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AppInlineMessage(message: _message, kind: _messageKind),
              AppPrimaryButton(
                label: 'تسجيل الدخول',
                enabled: _canSubmit,
                onDisabledTap: () => _show(_missingReason),
                busy: _busy,
                onTap: _login,
              ),
              const SizedBox(height: 8),
              // Secondary actions: register and (on the gate) guest mode.
              TextButton(
                onPressed: _busy ? null : _openRegister,
                child: Text(
                  'إنشاء حساب جديد',
                  style: TextStyle(
                    color: accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Outfit',
                    fontFamilyFallback: ['Tajawal'],
                  ),
                ),
              ),
              if (widget.allowGuest)
                TextButton(
                  onPressed: _busy ? null : _continueAsGuest,
                  child: Text(
                    'المتابعة كضيف',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Outfit',
                      fontFamilyFallback: ['Tajawal'],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
