// Signed-in account page: display name, email, change password, sign out,
// and account deletion.

import 'package:flutter/material.dart';
import 'package:waffr/widgets/motion/motion.dart';
import 'package:waffr/widgets/containers/app_list_tile.dart';
import 'package:waffr/data/services/backup_service.dart';
import 'package:waffr/core/sync/auth_session.dart';
import 'package:waffr/core/utils/app_feedback.dart';
import 'package:waffr/widgets/brand/profile_avatar.dart';
import 'package:waffr/widgets/brand/waffr_page_header.dart';
import 'package:waffr/core/prefs/app_prefs.dart';
import 'package:waffr/screens/offline/settings/change_password_screen.dart';
import 'package:waffr/core/theme/app_palette.dart';

/// Edit display name, change the password, sign out, or delete the synced
/// account. Opened from settings for signed-in users only.
class AccountScreen extends StatefulWidget {
  /// Runs the app-level sign-out (back to login). When null, the screen only
  /// clears the session.
  final Future<void> Function()? onSignedOut;

  /// Creates a [AccountScreen].
  const AccountScreen({super.key, this.onSignedOut});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

/// State of [AccountScreen]. Owns the display-name controller.
class _AccountScreenState extends State<AccountScreen> {
  final TextEditingController _nameController = TextEditingController();

  String _email = '';

  /// True while signing out or deleting; disables the action tiles.
  bool _busy = false;

  /// True while the display name is being written.
  bool _savingName = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Fills the name field from prefs and reads the account email.
  Future<void> _load() async {
    final prefs = await AppPrefs.instance;
    final email = await AuthSession.instance.email() ?? '';

    if (!mounted) return;

    setState(() {
      _email = email;
      _nameController.text = prefs.getString('user_name') ?? '';
    });
  }

  /// Writes the display name through BackupService (prefs plus a sync mark)
  /// and shows a snackbar.
  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _savingName) return;

    setState(() => _savingName = true);
    await BackupService.instance.updateDisplayName(name);
    if (!mounted) return;
    setState(() => _savingName = false);
    showAppSnackBar(context, 'تم حفظ الاسم', success: true);
  }

  /// Confirms, signs out (via the host's onSignedOut callback, or by clearing
  /// the session), then pops back to the first route.
  Future<void> _signOut() async {
    final confirm = await showAppConfirmDialog(
      context,
      title: 'تسجيل الخروج',
      message: 'سيتم تسجيل الخروج من حسابك على هذا الجهاز. تبقى بياناتك محفوظة هنا، وتعود إلى شاشة الدخول حيث يمكنك المتابعة كضيف أو تسجيل الدخول بحساب آخر.',
      confirmLabel: 'تسجيل الخروج',
    );

    if (confirm != true) return;

    setState(() => _busy = true);
    final signedOut = widget.onSignedOut;
    if (signedOut != null) {
      await signedOut();
    } else {
      await AuthSession.instance.clearSession();
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Confirms, deletes the account on the server, then wipes local data and
  /// backups and closes this page.
  Future<void> _deleteAccount() async {
    final confirm = await showAppConfirmDialog(
      context,
      title: 'حذف الحساب',
      message: 'سيتم حذف حسابك وكل بياناته من الخادم ومن هذا الجهاز ومن النسخة الاحتياطية إن وُجدت. لا يمكن التراجع عن هذا الإجراء.',
      confirmLabel: 'حذف الحساب',
      destructive: true,
    );

    if (confirm != true) return;

    setState(() => _busy = true);
    // Server first: if it fails, local data stays so the user can retry.
    final remote = await AuthSession.instance.deleteRemoteAccount();
    if (!remote.ok) {
      if (!mounted) return;
      setState(() => _busy = false);
      showAppSnackBar(context, remote.message);
      return;
    }
    await BackupService.instance.deleteAccount();
    if (!mounted) return;
    Navigator.of(context).pop();
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
      appBar: WaffrBackHeader(title: 'الحساب'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: staggered([
          // Avatar, name field and save button.
          Center(
            child: ProfileAvatar(accent: accent, radius: 42, signedIn: true),
          ),
          const SizedBox(height: 18),
          Text(
            'الاسم',
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            textAlign: TextAlign.right,
            style: TextStyle(color: textPrimary, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'الاسم المعروض',
              hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6)),
              filled: true,
              fillColor: surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _savingName ? null : _saveName,
              child: Text(
                _savingName ? 'جارٍ الحفظ...' : 'حفظ الاسم',
                style: TextStyle(
                  color: accent,
                  fontFamily: 'Outfit',
                  fontFamilyFallback: ['Tajawal'],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Read-only email.
          Text(
            'البريد الإلكتروني',
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _email.isEmpty ? '—' : _email,
              textDirection: TextDirection.ltr,
              style: TextStyle(color: textSecondary, fontSize: 15),
            ),
          ),
          const SizedBox(height: 25),
          // Account actions.
          AppListTile(
            icon: Icons.lock_reset_rounded,
            title: 'تغيير كلمة المرور',
            subtitle: 'يسجّل الخروج من أجهزتك الأخرى',
            busy: _busy,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
            ),
          ),
          const SizedBox(height: 12),
          AppListTile(
            icon: Icons.logout_rounded,
            title: 'تسجيل الخروج',
            subtitle: 'العودة إلى شاشة الدخول، والبيانات تبقى على الجهاز',
            busy: _busy,
            onTap: _signOut,
          ),
          const SizedBox(height: 12),
          AppListTile(
            icon: Icons.delete_forever_outlined,
            title: 'حذف الحساب',
            subtitle: 'حذف الحساب وبياناته من الخادم والجهاز',
            busy: _busy,
            onTap: _deleteAccount,
          ),
        ]),
      ),
    );
  }
}
