// App settings: account, income, currencies, obligations, theme, app lock,
// smart analysis, privacy, help, and the guest data reset.

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:waffr/widgets/motion/motion.dart';
import 'package:waffr/widgets/containers/app_list_tile.dart';
import 'package:waffr/data/stores/expense_preset_store.dart';
import 'package:waffr/data/stores/category_store.dart';
import 'package:waffr/data/stores/currency_store.dart';
import 'package:waffr/data/services/notification_service.dart';
import 'package:waffr/data/services/profile_identity.dart';
import 'package:waffr/data/services/usage_streak_service.dart';
import 'package:waffr/data/stores/recurring_expense_store.dart';
import 'package:waffr/data/stores/shopping_list_store.dart';
import 'package:waffr/data/models/transaction.dart';
import 'package:waffr/data/stores/transaction_store.dart';
import 'package:waffr/core/sync/auth_session.dart';
import 'package:waffr/core/sync/sync_service.dart';
import 'package:waffr/core/theme/app_palette.dart';
import 'package:waffr/core/utils/app_feedback.dart';
import 'package:waffr/core/utils/money.dart';
import 'package:waffr/screens/offline/login/login_screen.dart';
import 'package:waffr/screens/offline/settings/account_screen.dart';
import 'package:waffr/screens/offline/settings/ai_permissions_screen.dart';
import 'package:waffr/screens/offline/settings/help_screen.dart';
import 'package:waffr/screens/offline/settings/privacy_security_screen.dart';
import 'package:waffr/screens/offline/obligations/obligations_sheet.dart';
import 'package:waffr/screens/offline/settings/sheets/currencies_sheet.dart';
import 'package:waffr/screens/offline/settings/sheets/monthly_income_sheet.dart';
import 'package:waffr/widgets/brand/profile_avatar.dart';
import 'package:waffr/widgets/brand/waffr_page_header.dart';
import 'package:waffr/widgets/dialogs/edit_amount_dialog.dart';
import 'package:waffr/core/prefs/app_prefs.dart';
import 'package:waffr/widgets/smart/smart_glow.dart';

/// Hub for account, appearance, security shortcuts, and destructive data reset.
///
/// Pushed from the app shell. Most rows open their own screen or sheet in
/// this folder; the screen reloads its summary when they return.
class SettingsScreen extends StatefulWidget {
  /// App theme mode; the screen recolors when it changes.
  final ValueNotifier<ThemeMode> themeNotifier;

  /// Toggles the app theme (dark mode switch).
  final VoidCallback onThemeChanged;

  /// The root app flow state (from `main.dart`), or null. Used to refresh the
  /// app-lock state and to return to login after signing out.
  final dynamic appFlowController;

  /// Creates a [SettingsScreen].
  const SettingsScreen({
    super.key,
    required this.themeNotifier,
    required this.onThemeChanged,
    required this.appFlowController,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

/// State of [SettingsScreen]. Mirrors prefs, session and income into
/// fields, listens to the theme notifier, and owns the header elevation
/// notifier.
class _SettingsScreenState extends State<SettingsScreen> {
  /// Whether the app lock is on (prefs `app_lock`).
  bool _appLock = false;

  /// True while the device auth prompt is up; ignores further toggles.
  bool _isAuthenticating = false;

  String _userName = '';
  String _userEmail = '';
  bool _loggedIn = false;

  bool _hasMonthlyIncome = false;
  bool _hasWeeklyIncome = false;
  double _monthlyIncome = 0;
  double _weeklyIncome = 0;

  /// Weekly income stays in the store; the settings tile is hidden for now.
  static const bool _weeklyIncomeChoiceEnabled = false;

  /// Device biometrics / passcode prompt.
  final LocalAuthentication _auth = LocalAuthentication();

  /// True once the list has scrolled; drives the header shadow.
  final ValueNotifier<bool> _headerElevated = ValueNotifier(false);

  @override
  void initState() {
    super.initState();

    widget.themeNotifier.addListener(_onThemeChanged);

    _loadSettings();
  }

  @override
  void dispose() {
    widget.themeNotifier.removeListener(_onThemeChanged);
    _headerElevated.dispose();

    super.dispose();
  }

  /// Rebuilds with the new theme colors.
  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// Pulls prefs, auth session, and configured income into state.
  Future<void> _loadSettings() async {
    final prefs = await AppPrefs.instance;
    await TransactionStore.instance.ensureLoaded();

    final store = TransactionStore.instance;
    final accountEmail = await AuthSession.instance.email() ?? '';
    final loggedIn = await AuthSession.instance.isLoggedIn();

    if (!mounted) return;

    setState(() {
      _appLock = prefs.getBool('app_lock') ?? false;

      _loggedIn = loggedIn;

      _userName = prefs.getString('user_name') ?? '';

      _userEmail = loggedIn
          ? accountEmail
          : (prefs.getString('user_email') ?? '');

      _hasMonthlyIncome = store.hasConfiguredMonthlyIncome;
      _hasWeeklyIncome = store.hasWeeklyIncome;
      _monthlyIncome = store.configuredMonthlyIncome ?? 0;
      _weeklyIncome = store.referenceIncome(RecurringFrequency.weekly);
    });
  }

  /// Enables lock only after device auth succeeds; disable writes prefs
  /// immediately.
  Future<void> _toggleAppLock(bool value) async {
    if (_isAuthenticating) return;
    if (value) {
      await _enableAppLock();
    } else {
      await _disableAppLock();
    }
  }

  /// Asks for the fingerprint / device code before turning the lock on, then
  /// saves the flag and tells the app flow this session is authenticated.
  Future<void> _enableAppLock() async {
    setState(() {
      _isAuthenticating = true;
    });

    // Unsupported device: warn and leave the switch off.
    try {
      final supported = await _auth.isDeviceSupported();

      if (!supported) {
        if (!mounted) return;

        showAppSnackBar(
          context,
          'جهازك لا يدعم البصمة أو قفل الشاشة',
          kind: AppFeedbackKind.warning,
        );

        setState(() {
          _isAuthenticating = false;
        });

        return;
      }

      // Prompt; only a successful auth turns the lock on.
      final authenticated = await _auth.authenticate(
        localizedReason: 'تفعيل قفل التطبيق',
        biometricOnly: false,
      );

      if (!mounted) return;

      if (authenticated) {
        final prefs = await AppPrefs.instance;
        await prefs.setBool('app_lock', true);

        setState(() {
          _appLock = true;
        });

        widget.appFlowController?.refreshAppLockState(
          sessionAuthenticated: true,
        );

        if (mounted) {
          showAppSnackBar(context, 'تم تفعيل قفل التطبيق', success: true);
        }
      }
    } on LocalAuthException catch (_) {
      // Cancelled or failed: the switch simply stays off.
    } catch (_) {
      // Plugin errors are treated the same way.
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  /// Turns the lock off and tells the app flow.
  Future<void> _disableAppLock() async {
    final prefs = await AppPrefs.instance;
    await prefs.setBool('app_lock', false);

    if (!mounted) return;

    setState(() {
      _appLock = false;
    });

    if (widget.appFlowController != null) {
      widget.appFlowController.refreshAppLockState();
    }

    if (mounted) {
      showAppSnackBar(context, 'تم إيقاف قفل التطبيق', success: true);
    }
  }

  /// Explains that Arabic is currently the only supported language.
  void _showLanguageInfo() {
    showAppInfoDialog(
      context,
      title: 'اللغة',
      message: 'العربية هي اللغة الوحيدة المتاحة حالياً. نعمل على إضافة لغات أخرى في التحديثات القادمة.',
    );
  }

  /// Signed-in users open AccountScreen; guests go through LoginScreen first
  /// (and sync after signing in). Reloads the summary afterwards.
  Future<void> _openAccount() async {
    if (_loggedIn) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AccountScreen(
            onSignedOut: () async {
              await widget.appFlowController?.returnToLogin();
            },
          ),
        ),
      );
      if (!mounted) return;
      await _loadSettings();
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          allowGuest: false,
          popOnSuccess: true,
          onCompleted: () async {
            await SyncService.instance.syncNow();
          },
        ),
      ),
    );

    if (!mounted) return;
    await _loadSettings();
  }

  /// Edit or clear preferred monthly/weekly income in a sheet, not a dialog.
  Future<void> _editIncome(RecurringFrequency frequency) async {
    final isMonthly = frequency == RecurringFrequency.monthly;
    final current = isMonthly ? _monthlyIncome : _weeklyIncome;

    final result = await showMonthlyIncomeSheet(
      context,
      title: isMonthly ? 'الدخل الشهري' : 'الدخل الأسبوعي',
      initialAmount: current,
      allowClear: isMonthly && current > 0,
    );

    if (!mounted || result == null) return;

    // Cleared: drop the configured income for that currency.
    if (result is AmountDialogCleared) {
      final cleared = await TransactionStore.instance
          .clearPreferredIncomeAmount(
            frequency: frequency,
            currencyCode: result.currencyCode,
          );
      if (!mounted) return;
      if (!cleared) {
        showAppSnackBar(context, 'تعذّر إزالة الدخل. حاول مرة أخرى.');
        return;
      }
      await _loadSettings();
      if (!mounted) return;
      showAppSnackBar(
        context,
        isMonthly ? 'تمت إزالة الدخل الشهري' : 'تمت إزالة الدخل الأسبوعي',
        success: true,
      );
      return;
    }

    // New amount: save it for the chosen currency.
    if (result is! EditAmountResult) return;
    final amount = result.amount;

    final saved = await TransactionStore.instance.setPreferredIncomeAmount(
      frequency: frequency,
      amount: amount,
      currencyCode: result.currencyCode,
    );

    if (!mounted) return;

    if (!saved) {
      showAppSnackBar(context, 'تعذّر حفظ الدخل. حاول مرة أخرى.');
      return;
    }

    await _loadSettings();
    if (!mounted) return;

    showAppSnackBar(
      context,
      isMonthly ? 'تم حفظ دخلك الشهري' : 'تم حفظ دخلك الأسبوعي',
      success: true,
    );
  }

  /// The About text is not written yet, so the tile does nothing.
  void _showAbout() {}

  /// Clears prefs, session, and in-memory stores, then returns to first route.
  Future<void> _resetApp() async {
    final confirm = await showAppConfirmDialog(
      context,
      title: 'إعادة ضبط التطبيق',
      message: 'ستُحذف بياناتك الشخصية ورصيدك وسجل المصروفات من هذا الجهاز. لا يمكن التراجع عن هذا الإجراء.',
      confirmLabel: 'حذف البيانات',
      destructive: true,
    );

    if (confirm != true) return;

    // Wipe persisted data and the session.
    final prefs = await AppPrefs.instance;

    await prefs.clear();
    await AuthSession.instance.clearSession();
    await AuthSession.instance.clearDataOwner();

    // Drop every singleton's in-memory copy so nothing stale survives.
    TransactionStore.instance.resetCache();
    CurrencyStore.instance.resetCache();
    NotificationService.instance.resetCache();
    UsageStreakService.instance.resetCache();
    ProfileIdentity.instance.reset();
    ShoppingListStore.instance.resetCache();
    RecurringExpenseStore.instance.resetCache();
    CategoryStore.instance.resetCache();
    ExpensePresetStore.instance.resetCache();

    if (!mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Elevates the header once the list scrolls away from the top.
  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    final next = notification.metrics.pixels > 6;
    if (_headerElevated.value != next) {
      _headerElevated.value = next;
    }
    return false;
  }

  /// Opens the smart analysis permissions screen.
  void _openSmartSettings() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AIPermissionsScreen()));
  }

  /// Reloads afterwards: the privacy screen can sign out or turn the lock off.
  Future<void> _openPrivacySecurity() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PrivacySecurityScreen(appFlowController: widget.appFlowController),
      ),
    );
    await _loadSettings();
  }

  /// Opens the help screen.
  void _openHelp() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const HelpScreen()));
  }

  @override
  Widget build(BuildContext context) {
    // Colors follow the theme notifier this screen listens to.
    final isDark = widget.themeNotifier.value == ThemeMode.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            WaffrBackHeader(elevated: _headerElevated, title: 'الإعدادات'),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: staggered([
                    ..._accountSection(palette),
                    const SizedBox(height: 25),
                    ..._appearanceSection(isDark),
                    const SizedBox(height: 25),
                    ..._privacySection(),
                    const SizedBox(height: 25),
                    ..._supportSection(),
                    const SizedBox(height: 25),
                    ..._dataSection(),
                    // Version label.
                    Center(
                      child: Text(
                        'waffr 2.13.6',
                        style: TextStyle(
                          color: palette.textSecondary.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Profile card, income, currencies and obligations.
  List<Widget> _accountSection(AppPalette palette) {
    return [
      const AppSectionTitle(title: 'الحساب'),
      GestureDetector(
        onTap: _openAccount,
        child: _ProfileCard(
          name: _loggedIn
              ? (_userName.isEmpty ? 'حساب وفّر' : _userName)
              : 'لا يوجد حساب',
          email: _loggedIn ? _userEmail : 'اضغط لتسجيل الدخول أو إنشاء حساب',
          palette: palette,
          signedIn: _loggedIn,
        ),
      ),
      const SizedBox(height: 12),
      AppListTile(
        icon: Icons.payments_outlined,
        title: 'الدخل الشهري',
        subtitle: _hasMonthlyIncome
            ? '${formatMoney(_monthlyIncome)} $currencyLabel'
            : 'لم يُحدَّد بعد',
        onTap: () => _editIncome(RecurringFrequency.monthly),
      ),
      if (_weeklyIncomeChoiceEnabled && _hasWeeklyIncome) ...[
        const SizedBox(height: 12),
        AppListTile(
          icon: Icons.date_range_outlined,
          title: 'الدخل الأسبوعي',
          subtitle: '${formatMoney(_weeklyIncome)} $currencyLabel',
          onTap: () => _editIncome(RecurringFrequency.weekly),
        ),
      ],
      const SizedBox(height: 12),
      AppListTile(
        icon: Icons.currency_exchange_rounded,
        title: 'العملات',
        subtitle: 'إضافة عملة أو اختيار العملة النشطة',
        onTap: () => showCurrenciesSheet(context),
      ),
      const SizedBox(height: 12),
      AppListTile(
        icon: Icons.event_repeat_rounded,
        title: 'الالتزامات',
        subtitle: 'المصروفات المتكررة وطريقة خصمها',
        onTap: () => showObligationsSheet(context),
      ),
    ];
  }

  /// Dark mode switch and the language note.
  List<Widget> _appearanceSection(bool isDark) {
    return [
      const AppSectionTitle(title: 'المظهر'),
      AppListTile(
        icon: Icons.dark_mode_outlined,
        title: 'الوضع الداكن',
        subtitle: isDark ? 'مفعّل' : 'غير مفعّل',
        trailing: Switch(
          value: isDark,
          onChanged: (_) {
            widget.onThemeChanged();
          },
        ),
        onTap: widget.onThemeChanged,
      ),
      const SizedBox(height: 12),
      AppListTile(
        icon: Icons.language_rounded,
        title: 'اللغة',
        subtitle: 'العربية (اللغة الوحيدة المتاحة)',
        onTap: _showLanguageInfo,
      ),
    ];
  }

  /// App lock, smart analysis permissions and the privacy screen.
  List<Widget> _privacySection() {
    return [
      const AppSectionTitle(title: 'الحماية والخصوصية'),
      AppListTile(
        icon: Icons.lock_outline_rounded,
        title: 'قفل التطبيق',
        subtitle: 'طلب البصمة أو رمز الجهاز عند فتح وفّر',
        trailing: Switch(value: _appLock, onChanged: _toggleAppLock),
        onTap: () => _toggleAppLock(!_appLock),
      ),
      const SizedBox(height: 12),
      AppListTile(
        icon: Icons.auto_graph_rounded,
        leading: const SmartSpark(size: 32),
        title: 'التحليل الذكي',
        subtitle: 'ملاحظات واقتراحات وتنبيهات ذكية',
        onTap: _openSmartSettings,
      ),
      const SizedBox(height: 12),
      AppListTile(
        icon: Icons.privacy_tip_outlined,
        title: 'الخصوصية والأمان',
        subtitle: 'البيانات والمزامنة وحماية الجهاز',
        onTap: _openPrivacySecurity,
      ),
    ];
  }

  /// Help and about.
  List<Widget> _supportSection() {
    return [
      const AppSectionTitle(title: 'الدعم'),
      AppListTile(
        icon: Icons.help_outline_rounded,
        title: 'المساعدة',
        subtitle: 'الأسئلة الشائعة والدعم',
        onTap: _openHelp,
      ),
      const SizedBox(height: 12),
      AppListTile(
        icon: Icons.info_outline_rounded,
        title: 'عن وفّر',
        subtitle: 'معلومات عن التطبيق',
        onTap: _showAbout,
      ),
    ];
  }

  /// Guests get a full local reset; signed-in users manage data elsewhere.
  List<Widget> _dataSection() {
    if (_loggedIn) return const [SizedBox(height: 5)];
    return [
      const AppSectionTitle(title: 'البيانات'),
      AppListTile(
        icon: Icons.delete_outline_rounded,
        title: 'إعادة ضبط التطبيق',
        subtitle: 'حذف جميع البيانات والبدء من جديد',
        onTap: _resetApp,
      ),
      const SizedBox(height: 30),
    ];
  }
}

/// Avatar + name/email card at the top of settings (or a sign-in prompt).
class _ProfileCard extends StatelessWidget {
  final String name;
  final String email;
  final bool signedIn;
  final AppPalette palette;

  const _ProfileCard({
    required this.name,
    required this.email,
    required this.palette,
    required this.signedIn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          ProfileAvatar(accent: palette.accent, radius: 27, signedIn: signedIn),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'المستخدم' : name,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
