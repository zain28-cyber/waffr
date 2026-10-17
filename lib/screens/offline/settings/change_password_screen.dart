// Change the account password. Other devices are signed out; data stays.

import 'package:flutter/material.dart';
import 'package:waffr/widgets/button/app_primary_button.dart';
import 'package:waffr/core/sync/auth_session.dart';
import 'package:waffr/core/utils/app_feedback.dart';
import 'package:waffr/screens/offline/login/auth_fields.dart';
import 'package:waffr/widgets/brand/waffr_page_header.dart';
import 'package:waffr/core/theme/app_palette.dart';

/// Form for changing the account password (current, new, confirm). Opened
/// from the account page; calls `AuthSession.changePassword`.
class ChangePasswordScreen extends StatefulWidget {
  /// Creates a [ChangePasswordScreen].
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

/// State of [ChangePasswordScreen]. Owns the three password controllers
/// and the inline message shown above the save button.
class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  /// True while the request is in flight; locks the fields and back button.
  bool _busy = false;

  /// Shown above the main button; cleared as soon as a field changes.
  String? _message;
  AppFeedbackKind _messageKind = AppFeedbackKind.error;

  /// Hides all three fields; toggled by the eye icon on the first one.
  bool _obscure = true;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// Current filled, new at least 8 chars, matching, and different.
  bool get _canSave {
    final next = _newController.text;
    return _currentController.text.isNotEmpty &&
        next.length >= 8 &&
        next == _confirmController.text &&
        next != _currentController.text &&
        !_busy;
  }

  /// Sends the change; on success pops with a snackbar, otherwise shows the
  /// server message inline.
  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _busy = true);
    final result = await AuthSession.instance.changePassword(
      currentPassword: _currentController.text,
      newPassword: _newController.text,
    );
    if (!mounted) return;
    if (!result.ok) {
      setState(() => _busy = false);
      _show(result.message);
      return;
    }
    showAppSnackBar(context, 'تم تغيير كلمة المرور', success: true);
    Navigator.of(context).pop();
  }

  /// Sets the inline message and its kind.
  void _show(String? message, {bool success = false}) {
    setState(() {
      _message = message;
      _messageKind = success ? AppFeedbackKind.success : AppFeedbackKind.error;
    });
  }

  /// Why the main button is disabled, in plain words.
  String? get _missingReason {
    final next = _newController.text;
    if (_currentController.text.isEmpty) return 'أدخل كلمة المرور الحالية';
    if (next.length < 8) {
      return 'كلمة المرور الجديدة يجب أن تتكون من 8 أحرف على الأقل';
    }
    if (next != _confirmController.text) return 'كلمتا المرور غير متطابقتين';
    if (next == _currentController.text) {
      return 'اختر كلمة مرور جديدة تختلف عن الحالية';
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

    // Labeled password field shared by the three inputs.
    Widget field(
      String label,
      TextEditingController controller,
      String hint, {
      Widget? suffixIcon,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthFieldLabel(text: label, color: textPrimary),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            enabled: !_busy,
            obscureText: _obscure,
            onChanged: (_) => setState(() => _message = null),
            style: TextStyle(color: textPrimary, fontSize: 16),
            decoration: authFieldDecoration(
              hint: hint,
              fillColor: surface,
              textSecondary: textSecondary,
              suffixIcon: suffixIcon,
            ),
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: WaffrBackHeader(enabled: !_busy, title: 'تغيير كلمة المرور'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Current, new and confirm fields; the eye toggle sits on the first.
          field(
            'كلمة المرور الحالية',
            _currentController,
            '••••••••',
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
          field('كلمة المرور الجديدة', _newController, '8 أحرف على الأقل'),
          field(
            'تأكيد كلمة المرور الجديدة',
            _confirmController,
            'أعد كتابة كلمة المرور',
          ),
          // Sign-out note, inline message and save.
          Text(
            'سيتم تسجيل الخروج من أجهزتك الأخرى. بياناتك تبقى كما هي.',
            style: TextStyle(color: textSecondary, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 20),
          AppInlineMessage(message: _message, kind: _messageKind),
          AppPrimaryButton(
            label: 'حفظ',
            enabled: _canSave,
            onDisabledTap: () => _show(_missingReason),
            busy: _busy,
            onTap: _save,
          ),
        ],
      ),
    );
  }
}
