// Privacy & security detail pages: account data, cloud sync, synced data,
// app lock and local reset, each opened from a row of the main screen.

part of 'privacy_security_screen.dart';

/// Explains what account fields are stored and how financial data stays private.
class _AccountDataDetailPage extends StatelessWidget {
  const _AccountDataDetailPage();

  @override
  Widget build(BuildContext context) {
    final colors = _PrivacyColors.of(context);

    return _PrivacyDetailScaffold(
      title: 'بيانات الحساب',
      colors: colors,
      children: [
        _DetailLead(
          icon: Icons.badge_outlined,
          colors: colors,
          text: 'يحتفظ وفّر بمعلومات أساسية لتشغيل الحساب وعرض الملف الشخصي.',
        ),
        const SizedBox(height: 16),
        _InfoGroup(
          colors: colors,
          children: const [
            _InfoLine(label: 'الاسم المعروض'),
            _InfoLine(label: 'البريد الإلكتروني'),
            _InfoLine(label: 'الجنس، إن تم إدخاله'),
            _InfoLine(label: 'تاريخ الميلاد'),
            _InfoLine(
              label: 'صورة الملف الشخصي على هذا الجهاز',
              showDivider: false,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _NoteText(
          colors: colors,
          text: 'عند تسجيل الدخول، تُزامَن معلومات الملف الشخصي ذات الصلة مع الحساب. صورة الملف الشخصي تبقى محفوظة محلياً على الجهاز.',
        ),
      ],
    );
  }
}

/// Cloud sync status and how backups relate to a signed-in account; the copy
/// differs for guests.
class _CloudSyncDetailPage extends StatelessWidget {
  final bool loggedIn;

  const _CloudSyncDetailPage({required this.loggedIn});

  @override
  Widget build(BuildContext context) {
    final colors = _PrivacyColors.of(context);

    return _PrivacyDetailScaffold(
      title: 'المزامنة السحابية',
      colors: colors,
      children: [
        _StatusBanner(
          colors: colors,
          emphasized: loggedIn,
          title: loggedIn ? 'مفعّلة' : 'غير متاحة في وضع الضيف',
          subtitle: loggedIn
              ? 'مرتبطة بالحساب الذي سجّلت الدخول إليه.'
              : 'لا تتم مزامنة سحابية أثناء استخدام التطبيق كضيف.',
        ),
        const SizedBox(height: 16),
        _InfoGroup(
          colors: colors,
          children: loggedIn
              ? const [
                  _InfoLine(
                    label: 'تُحفظ بياناتك على الجهاز أولاً، فيعمل التطبيق دون اتصال.',
                  ),
                  _InfoLine(
                    label: 'عند توفر الاتصال، تُزامَن تلقائياً مع خوادم وفّر.',
                  ),
                  _InfoLine(
                    label: 'بيانات كل حساب منفصلة عن غيره، ولا يصل إليها إلا صاحبها.',
                    showDivider: false,
                  ),
                ]
              : const [
                  _InfoLine(label: 'تبقى بياناتك محفوظة على هذا الجهاز.'),
                  _InfoLine(
                    label: 'لا تُرسل البيانات إلى السحابة في وضع الضيف.',
                  ),
                  _InfoLine(
                    label: 'بعد تسجيل الدخول، تُزامَن بياناتك تلقائياً عند توفر الاتصال.',
                    showDivider: false,
                  ),
                ],
        ),
      ],
    );
  }
}

/// Lists which local datasets participate in sync and which stay on the
/// device.
class _SyncedDataDetailPage extends StatelessWidget {
  const _SyncedDataDetailPage();

  /// Data that syncs with the account.
  static const _synced = <String>[
    'المعاملات المالية',
    'أهداف التوفير والتحويلات',
    'الالتزامات (المصروفات المتكررة)',
    'قوائم التسوق وعناصرها',
    'الإشعارات',
    'التصنيفات المخصصة',
    'إعدادات المستخدم',
    'معلومات الملف الشخصي ذات الصلة',
  ];

  /// Data that never leaves the device.
  static const _localOnly = <String>[
    'إعدادات قفل التطبيق',
    'بيانات تسجيل الدخول',
    'ملفات صور الملف الشخصي المحلية',
    'بيانات خاصة بالجهاز',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _PrivacyColors.of(context);

    return _PrivacyDetailScaffold(
      title: 'البيانات المتزامنة',
      colors: colors,
      children: [
        _NoteText(
          colors: colors,
          text: 'تُزامَن البيانات التالية مع الحساب عند تسجيل الدخول وتوفر الاتصال.',
        ),
        const SizedBox(height: 16),
        AppSectionTitle(title: 'تُزامَن مع الحساب'),
        _InfoGroup(
          colors: colors,
          children: [
            for (var i = 0; i < _synced.length; i++)
              _InfoLine(
                label: _synced[i],
                showDivider: i != _synced.length - 1,
              ),
          ],
        ),
        const SizedBox(height: 22),
        AppSectionTitle(title: 'تبقى على الجهاز'),
        _InfoGroup(
          colors: colors,
          children: [
            for (var i = 0; i < _localOnly.length; i++)
              _InfoLine(
                label: _localOnly[i],
                showDivider: i != _localOnly.length - 1,
              ),
          ],
        ),
      ],
    );
  }
}

/// Toggle device app lock with biometric/passcode confirmation.
class _AppLockDetailPage extends StatefulWidget {
  final dynamic appFlowController;
  final LocalAuthentication auth;
  final bool initiallyEnabled;

  const _AppLockDetailPage({
    required this.appFlowController,
    required this.auth,
    required this.initiallyEnabled,
  });

  @override
  State<_AppLockDetailPage> createState() => _AppLockDetailPageState();
}

/// State of [_AppLockDetailPage]. Mirrors the lock flag locally so the
/// switch updates without a reload.
class _AppLockDetailPageState extends State<_AppLockDetailPage> {
  late bool _enabled;

  /// True while the auth prompt / prefs write is running.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initiallyEnabled;
  }

  /// Enables after device auth; disables by clearing AppLock prefs. Tells the
  /// app flow either way and shows the outcome in a snackbar.
  Future<void> _toggle(bool value) async {
    if (_busy) return;

    setState(() => _busy = true);

    final result = await AppLock.setEnabled(
      enabled: value,
      auth: widget.auth,
      onEnabled: () {
        widget.appFlowController?.refreshAppLockState(
          sessionAuthenticated: true,
        );
      },
      onDisabled: () {
        widget.appFlowController?.refreshAppLockState();
      },
    );

    if (!mounted) return;

    setState(() {
      _busy = false;
      if (result == AppLockToggleResult.enabled) {
        _enabled = true;
      } else if (result == AppLockToggleResult.disabled) {
        _enabled = false;
      }
    });

    switch (result) {
      case AppLockToggleResult.enabled:
        showAppSnackBar(context, 'تم تفعيل قفل التطبيق', success: true);
      case AppLockToggleResult.disabled:
        showAppSnackBar(context, 'تم إيقاف قفل التطبيق', success: true);
      case AppLockToggleResult.unsupported:
        showAppSnackBar(
          context,
          'جهازك لا يدعم البصمة أو قفل الشاشة',
          kind: AppFeedbackKind.warning,
        );
      case AppLockToggleResult.cancelled:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _PrivacyColors.of(context);

    return _PrivacyDetailScaffold(
      title: 'قفل التطبيق',
      colors: colors,
      children: [
        _StatusBanner(
          colors: colors,
          emphasized: _enabled,
          title: _enabled ? 'مفعّل' : 'غير مفعّل',
          subtitle: 'يحمي الوصول إلى وفّر على هذا الجهاز.',
        ),
        const SizedBox(height: 16),
        _InfoGroup(
          colors: colors,
          children: const [
            _InfoLine(
              label: 'يستخدم قفل التطبيق مصادقة الجهاز، مثل البصمة أو التعرف على الوجه أو رمز الجهاز.',
            ),
            _InfoLine(
              label: 'يمنع فتح التطبيق على هذا الجهاز دون تأكيد هويتك.',
            ),
            _InfoLine(
              label: 'هذا الإعداد يبقى على الجهاز ولا يُزامَن مع الحساب.',
              showDivider: false,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsGroup(
          children: [
            _SettingsRow(
              icon: Icons.lock_outline_rounded,
              title: 'قفل التطبيق',
              showChevron: false,
              trailing: Switch(
                value: _enabled,
                onChanged: _busy ? null : _toggle,
              ),
              onTap: _busy ? null : () => _toggle(!_enabled),
            ),
          ],
        ),
      ],
    );
  }
}

/// Wipe local app data on this device (the server account is untouched),
/// then return to the first route.
class _LocalResetDetailPage extends StatelessWidget {
  const _LocalResetDetailPage();

  /// Confirms, runs `LocalDataReset.resetCurrentDevice`, then pops to the
  /// first route.
  Future<void> _confirmReset(BuildContext context) async {
    final confirm = await showAppConfirmDialog(
      context,
      title: 'إعادة ضبط البيانات المحلية',
      message: 'سيتم حذف البيانات المخزّنة على هذا الجهاز. لا يمكن التراجع عن هذا الإجراء.',
      confirmLabel: 'حذف البيانات',
      destructive: true,
    );

    if (confirm != true || !context.mounted) return;

    await LocalDataReset.resetCurrentDevice();
    if (!context.mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _PrivacyColors.of(context);

    return _PrivacyDetailScaffold(
      title: 'إعادة ضبط البيانات المحلية',
      colors: colors,
      children: [
        _DetailLead(
          icon: Icons.delete_outline_rounded,
          colors: colors,
          text: 'يؤثر هذا الإجراء على البيانات المخزّنة على الجهاز الحالي فقط.',
        ),
        const SizedBox(height: 16),
        _InfoGroup(
          colors: colors,
          children: const [
            _InfoLine(
              label: 'سيتم حذف البيانات المالية المحلية وإعدادات هذا الجهاز.',
            ),
            _InfoLine(label: 'لا يمكن التراجع عن هذا الإجراء بعد تأكيده.'),
            _InfoLine(
              label: 'لا يحذف هذا الإجراء حسابك من الخادم. لحذف الحساب استخدم شاشة الحساب بعد تسجيل الدخول.',
              showDivider: false,
            ),
          ],
        ),
        const SizedBox(height: 22),
        AppPrimaryButton(
          label: 'إعادة ضبط هذا الجهاز',
          onTap: () => _confirmReset(context),
        ),
      ],
    );
  }
}
