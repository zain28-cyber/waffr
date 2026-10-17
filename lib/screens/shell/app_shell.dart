// The signed-in app shell: header, lazily built tab pager, floating bottom
// navigation bar, and the background work that runs while the app is open
// (due periods, reminders, home-widget and notification taps).

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:waffr/data/stores/category_store.dart';
import 'package:waffr/data/services/home_widget_sync.dart';
import 'package:waffr/data/services/notification_service.dart';
import 'package:waffr/data/services/profile_identity.dart';
import 'package:waffr/data/services/system_notifications.dart';
import 'package:waffr/data/services/usage_streak_service.dart';
import 'package:waffr/data/stores/recurring_expense_store.dart';
import 'package:waffr/data/stores/transaction_store.dart';
import 'package:waffr/core/theme/app_motion.dart';
import 'package:waffr/core/utils/app_feedback.dart';
import 'package:waffr/screens/offline/home/dashboard.dart';
import 'package:waffr/screens/offline/home/sheets/add_expense_sheet.dart';
import 'package:waffr/screens/offline/home/sheets/add_income_sheet.dart';
import 'package:waffr/screens/offline/obligations/obligations_sheet.dart';
import 'package:waffr/screens/offline/savings/sheets/create_goal_sheet.dart';
import 'package:waffr/screens/offline/notifications/notifications_screen.dart';
import 'package:waffr/screens/offline/profile/profile_screen.dart';
import 'package:waffr/screens/online/online_screen.dart';
import 'package:waffr/screens/offline/report/reportscreen.dart';
import 'package:waffr/screens/offline/savings/savings_screen.dart';
import 'package:waffr/screens/offline/settings/settings_screen.dart';
import 'package:waffr/screens/shell/app_shell_scope.dart';
import 'package:waffr/widgets/brand/streak_celebration.dart';
import 'package:waffr/widgets/brand/waffr_page_header.dart';
import 'package:waffr/widgets/button/glass_button.dart';
import 'package:waffr/widgets/containers/floating_glass.dart';
import 'package:waffr/screens/offline/smart/smart_analysis_screen.dart';
import 'package:waffr/data/services/smart_settings.dart';
import 'package:waffr/core/insights/smart/smart_insight.dart';
import 'package:waffr/core/insights/smart/smart_facts_loader.dart';
import 'package:waffr/core/insights/smart/reminder_digest.dart';
import 'package:waffr/core/theme/app_palette.dart';

/// Bottom navigation shell. Five tabs: home, report, savings, online, profile.
/// The tab bar floats over the pages; each tab keeps [kFloatingNavClearance]
/// free at the bottom of its scroll content.
/// Settings and notifications are pushed from the header, not tabs.
class AppShell extends StatefulWidget {
  /// Current theme mode, handed through to the settings screen.
  final ValueNotifier<ThemeMode> themeNotifier;

  /// Toggles light/dark; handed through to the settings screen.
  final VoidCallback onThemeChanged;

  /// The app's flow-controller state (from `main.dart`), handed to settings
  /// so it can sign out or refresh the app-lock gate.
  final dynamic appFlowController;

  /// Creates a [AppShell].
  const AppShell({
    super.key,
    required this.themeNotifier,
    required this.onThemeChanged,
    required this.appFlowController,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

/// State of [AppShell]. Owns the page controller, the selected-tab notifier,
/// the per-minute due-events timer, and the home-widget / notification tap
/// subscriptions.
class _AppShellState extends State<AppShell>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  /// Selected tab; the bar, the tab tickers and the profile page listen.
  final ValueNotifier<int> _tabIndex = ValueNotifier<int>(0);
  final PageController _pageController = PageController();

  /// Target page while a tap-driven switch is in flight; pages the pager
  /// passes on the way are not reported as the selected tab.
  int? _animatingToPage;

  /// Pager opacity for the fade-through used on tabs that are not neighbors.
  late final AnimationController _pagerFade = AnimationController(
    vsync: this,
    value: 1,
  );

  /// Re-runs [_syncFinancialEvents] every minute while in the foreground.
  Timer? _dueTimer;

  /// Guards [_syncFinancialEvents] against overlapping runs.
  bool _syncingEvents = false;

  /// Home-screen widget taps.
  StreamSubscription<Uri?>? _widgetTaps;

  /// System notification taps.
  StreamSubscription<String>? _notificationTaps;

  /// Set when today's open extended the streak; drives the overlay once.
  StreakIncrease? _streakIncrease;

  static const int _tabCount = 5;

  /// Lazy tab cache: [_tabAt] builds a page on first visit and reuses it.
  /// Each tab uses AutomaticKeepAliveClientMixin so scroll position survives
  /// after the first visit; unopened tabs are never built.
  final List<Widget?> _builtTabs = List<Widget?>.filled(_tabCount, null);

  /// Creates the page for [index] once, then returns the cached widget.
  Widget _tabAt(int index) {
    final existing = _builtTabs[index];
    if (existing != null) return existing;

    final Widget page = switch (index) {
      0 => const HomeScreen(),
      1 => const ReportScreen(),
      2 => const SavingsScreen(),
      3 => const OnlineScreen(),
      _ => ProfileScreen(tabIndex: _tabIndex),
    };
    // Keep tab state, but mute its tickers and store-driven builders when
    // another tab is selected. The child stays cached across switches.
    final tab = ValueListenableBuilder<int>(
      valueListenable: _tabIndex,
      child: page,
      builder: (context, selected, child) => TickerMode(
        enabled: selected == index,
        // Retained pages must not expose duplicate controls to screen readers
        // while the next tab's period selector is on screen.
        child: ExcludeSemantics(excluding: selected != index, child: child!),
      ),
    );
    _builtTabs[index] = tab;
    return tab;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startDueTimer();
    _syncFinancialEvents();
    unawaited(HomeWidgetSync.instance.start());
    _listenToWidgetTaps();
    _listenToNotificationTaps();
    unawaited(_syncComebackReminders());
  }

  /// Reminders that only fire if the app stays closed for days; every open
  /// pushes them forward. Each states a fact from the user's own numbers.
  Future<void> _syncComebackReminders() async {
    final settings = SmartSettings.instance;
    final notifications = NotificationService.instance;
    await Future.wait([settings.ensureLoaded(), notifications.ensureLoaded()]);
    final enabled = settings.alerts && !notifications.isMuted;
    (String, String)? soon;
    (String, String)? later;
    (String, String)? weekly;
    // Pick the first and second reminder from different kinds, plus the
    // weekly digest; all stay null when alerts are off.
    if (enabled) {
      final facts = await SmartFactsLoader.load();
      final digest = ReminderDigest(facts);
      final first = digest.candidates(SystemNotifications.soonAt(facts.now));
      final second = digest
          .candidates(SystemNotifications.laterAt(facts.now))
          .where((item) => first.isEmpty || item.kind != first.first.kind);
      if (first.isNotEmpty) soon = (first.first.title, first.first.body);
      if (second.isNotEmpty) later = (second.first.title, second.first.body);
      final week = digest.weekly();
      if (week != null) weekly = (week.title, week.body);
    }
    await SystemNotifications.instance.syncComebackReminders(
      enabled: enabled,
      soon: soon,
      later: later,
      weekly: weekly,
    );
  }

  /// Smart reminders open the analysis, both on cold launch and while open.
  void _listenToNotificationTaps() {
    final system = SystemNotifications.instance;
    system.launchPayload().then(_openFromNotification);
    _notificationTaps = system.taps.listen(_openFromNotification);
  }

  /// Opens the smart analysis on top of the shell for a smart-reminder tap.
  void _openFromNotification(String? payload) {
    if (payload != SystemNotifications.smartPayload) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      openSmartAnalysis(context, InsightScope.reports);
    });
  }

  /// A tap on a home screen widget opens the app on the matching place.
  void _listenToWidgetTaps() {
    if (!HomeWidgetSync.supported) return;
    HomeWidget.initiallyLaunchedFromHomeWidget()
        .then(_openFromWidget)
        .catchError((Object _) {});
    _widgetTaps = HomeWidget.widgetClicked.listen(
      _openFromWidget,
      onError: (Object _) {},
    );
  }

  /// Routes a widget deep link (by URI host) to a tab and/or sheet.
  void _openFromWidget(Uri? uri) {
    if (uri == null || uri.host.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      switch (uri.host) {
        case 'add-expense':
          _onTabTapped(0);
          showAddExpenseSheet(context);
        case 'add-income':
          _onTabTapped(0);
          showAddIncomeSheet(context);
        case 'savings':
          _onTabTapped(2);
        case 'create-goal':
          _onTabTapped(2);
          showCreateGoalSheet(context);
        case 'obligations':
          showObligationsSheet(context);
        case 'profile':
          _onTabTapped(4);
        default:
          _onTabTapped(0);
      }
    });
  }

  /// (Re)starts the one-minute [_dueTimer].
  void _startDueTimer() {
    _dueTimer?.cancel();
    _dueTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _syncFinancialEvents();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startDueTimer();
      _syncFinancialEvents();
      unawaited(_syncComebackReminders());
      ProfileIdentity.instance.reload();
    } else if (state == AppLifecycleState.paused) {
      _dueTimer?.cancel();
      _dueTimer = null;
    }
  }

  /// Due periods, recurring expenses, streak, and notification evaluation.
  Future<void> _syncFinancialEvents() async {
    if (_syncingEvents) return;
    _syncingEvents = true;
    try {
      final notifications = NotificationService.instance;
      await notifications.ensureLoaded();
      notifications.listen();
      await TransactionStore.instance.processDuePeriods();
      await RecurringExpenseStore.instance.ensureLoaded();
      await RecurringExpenseStore.instance.processDue();
      await CategoryStore.instance.ensureLoaded();
      await notifications.evaluate();
      final streak = await UsageStreakService.instance.recordToday();
      await SystemNotifications.instance.syncStreakReminder(
        enabled: !notifications.isMuted && streak.count >= 2,
        streakCount: streak.count,
      );
      _showStreakIncrease(UsageStreakService.instance.takeIncrease());
    } finally {
      _syncingEvents = false;
    }
  }

  /// Shows the streak overlay after a short delay so the home screen can
  /// settle on screen first.
  Future<void> _showStreakIncrease(StreakIncrease? increase) async {
    if (increase == null) return;
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() => _streakIncrease = increase);
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
    );
  }

  /// Long press on the bell: mute or unmute without opening the list.
  Future<void> _toggleNotificationsMuted() async {
    final service = NotificationService.instance;
    await service.ensureLoaded();
    await service.toggleMuted();
    if (!mounted) return;
    AppHaptics.success();
    showAppSnackBar(
      context,
      service.isMuted ? 'تم كتم الإشعارات' : 'تم تفعيل الإشعارات',
      kind: AppFeedbackKind.info,
    );
  }

  /// Pushes settings, then reloads [ProfileIdentity] in case the account
  /// changed there.
  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          themeNotifier: widget.themeNotifier,
          onThemeChanged: widget.onThemeChanged,
          appFlowController: widget.appFlowController,
        ),
      ),
    );
    if (!mounted) return;
    await ProfileIdentity.instance.reload();
  }

  /// The bar highlight moves with the tap. Neighbor tabs slide; farther tabs
  /// fade through, so the pager never sweeps past (and builds) the tabs
  /// between them.
  void _onTabTapped(int index) {
    if (index == _tabIndex.value && _animatingToPage == null) return;
    if (_animatingToPage == index) return;

    final from = _pageController.hasClients
        ? (_pageController.page?.round() ?? _tabIndex.value)
        : _tabIndex.value;

    _tabIndex.value = index;
    if (!_pageController.hasClients) return;
    _animatingToPage = index;

    if ((index - from).abs() > 1 || AppMotion.reduced(context)) {
      _fadeThroughTo(index);
      return;
    }

    // A fade-through still running is cut short and the pager shown again.
    if (_pagerFade.value < 1) {
      _pagerFade.animateTo(1, duration: AppMotion.fast, curve: AppMotion.enter);
    }
    _pageController
        .animateToPage(
          index,
          duration: AppMotion.medium,
          curve: AppMotion.standard,
        )
        .whenComplete(() => _settleTap(index));
  }

  /// Fades the pager out, jumps to [index], and fades back in.
  Future<void> _fadeThroughTo(int index) async {
    final reduced = AppMotion.reduced(context);
    if (!reduced) {
      try {
        await _pagerFade
            .animateTo(0, duration: AppMotion.instant, curve: AppMotion.exit)
            .orCancel;
      } on TickerCanceled {
        return;
      }
    }
    if (!mounted || _animatingToPage != index) return;
    _pageController.jumpToPage(index);
    _settleTap(index);
    if (!reduced) {
      _pagerFade.animateTo(1, duration: AppMotion.fast, curve: AppMotion.enter);
    } else {
      _pagerFade.value = 1;
    }
  }

  /// Tap switch finished; the pager's resting page is the selected tab.
  void _settleTap(int index) {
    if (!mounted) return;
    if (_animatingToPage != index) return;
    _animatingToPage = null;
    final settled = _pageController.hasClients
        ? _pageController.page?.round()
        : null;
    if (settled != null && settled != _tabIndex.value) {
      _tabIndex.value = settled;
    }
  }

  /// Swipe settled (or ignored while a conflicting tap animation is in
  /// flight).
  void _onPageChanged(int index) {
    if (_animatingToPage != null && index != _animatingToPage) {
      return;
    }
    _animatingToPage = null;
    if (index == _tabIndex.value) return;
    _tabIndex.value = index;
  }

  @override
  void dispose() {
    _dueTimer?.cancel();
    _widgetTaps?.cancel();
    _notificationTaps?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _pagerFade.dispose();
    _tabIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final bg = palette.background;

    final increase = _streakIncrease;

    return AppShellScope(
      selectTab: _onTabTapped,
      child: Scaffold(
        backgroundColor: bg,
        // No tab has a text field; sheets handle the keyboard themselves.
        // Resizing here would re-lay out the visible tab on every keyboard
        // frame behind an open sheet.
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Header (settings, bell, wordmark) above the tab pager.
            SafeArea(
              // The header paints under the status bar so the two read as
              // one surface; it applies the top inset itself.
              top: false,
              child: Column(
                children: [
                  WaffrPageHeader(
                    leadingWidth: 104,
                    leading: Row(
                      children: [
                        GlassIconButton(
                          icon: Icons.settings_rounded,
                          label: 'الإعدادات',
                          onPressed: _openSettings,
                        ),
                        const SizedBox(width: 8),
                        _NotificationsButton(
                          onPressed: _openNotifications,
                          onLongPress: _toggleNotificationsMuted,
                        ),
                      ],
                    ),
                    title: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'WAFFR',
                        style: Theme.of(context).textTheme.displayLarge
                            ?.copyWith(
                              fontFamily: 'BebasNeue',
                              fontStyle: FontStyle.italic,
                            ),
                      ),
                    ),
                  ),
                  Expanded(
                    // Only the visible page is built: zero viewport cache and no
                    // implicit neighbor scrolling. Pages come from _tabAt.
                    child: FadeTransition(
                      opacity: _pagerFade,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _tabCount,
                        allowImplicitScrolling: false,
                        scrollCacheExtent: const ScrollCacheExtent.viewport(0),
                        onPageChanged: _onPageChanged,
                        itemBuilder: (context, index) => _tabAt(index),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Floats over the pages so content scrolls under its blur.
            // Hidden while the keyboard is up so it never covers a field.
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 10,
              child: _HideOnKeyboard(
                child: RepaintBoundary(
                  child: _BottomNavBar(
                    tabIndex: _tabIndex,
                    tabCount: _tabCount,
                    pageController: _pageController,
                    onTap: _onTabTapped,
                  ),
                ),
              ),
            ),
            // One-shot streak celebration over everything.
            if (increase != null)
              Positioned.fill(
                child: StreakCelebrationOverlay(
                  key: ValueKey('streak-${increase.to}'),
                  from: increase.from,
                  to: increase.to,
                  onFinished: () {
                    if (mounted) setState(() => _streakIncrease = null);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Slides the nav bar away while the keyboard is up so it never covers a
/// field. Only this small widget depends on the keyboard inset, so the
/// shell itself does not rebuild on every keyboard frame.
class _HideOnKeyboard extends StatelessWidget {
  final Widget child;

  const _HideOnKeyboard({required this.child});

  @override
  Widget build(BuildContext context) {
    final hidden = MediaQuery.viewInsetsOf(context).bottom > 0;
    final duration = AppMotion.of(context, AppMotion.fast);
    return IgnorePointer(
      ignoring: hidden,
      child: AnimatedSlide(
        offset: hidden ? const Offset(0, 1.6) : Offset.zero,
        duration: duration,
        curve: hidden ? AppMotion.exit : AppMotion.enter,
        child: AnimatedOpacity(
          opacity: hidden ? 0 : 1,
          duration: duration,
          child: child,
        ),
      ),
    );
  }
}

/// Floating "liquid glass" tab bar: a blurred, translucent pill over the
/// pages. The highlight follows the pager position, stretching while it moves
/// between tabs and settling round under the selected icon.
class _BottomNavBar extends StatelessWidget {
  final ValueNotifier<int> tabIndex;
  final int tabCount;
  final PageController pageController;
  final ValueChanged<int> onTap;

  const _BottomNavBar({
    required this.tabIndex,
    required this.tabCount,
    required this.pageController,
    required this.onTap,
  });

  /// Tab icons, in page order.
  static const List<IconData> _icons = [
    Icons.home_rounded,
    Icons.bar_chart_rounded,
    Icons.wallet_rounded,
    Icons.public_rounded,
    Icons.person_rounded,
  ];

  /// Screen-reader labels, in page order.
  static const List<String> _labels = [
    'الرئيسية',
    'التقارير',
    'التوفير',
    'الإنترنت',
    'الملف الشخصي',
  ];

  static const double _height = 64;
  static const BorderRadius _radius = BorderRadius.all(Radius.circular(32));

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final textPrimary = palette.textPrimary;
    final accent = palette.accent;
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return FloatingGlass(
      radius: _radius,
      child: SizedBox(
        height: _height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slot = constraints.maxWidth / tabCount;
            return AnimatedBuilder(
              animation: Listenable.merge([pageController, tabIndex]),
              builder: (context, _) {
                final page =
                    pageController.hasClients &&
                        pageController.position.haveDimensions
                    ? (pageController.page ?? tabIndex.value.toDouble())
                    : tabIndex.value.toDouble();
                return Stack(
                  children: [
                    _indicator(page, slot, rtl),
                    Row(
                      children: [
                        for (var i = 0; i < tabCount; i++)
                          Expanded(child: _tab(i, page, accent, textPrimary)),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Highlight bubble for the fractional pager [page]: widest and flattest
  /// halfway between two tabs, mirrored in RTL.
  Widget _indicator(double page, double slot, bool rtl) {
    final frac = page - page.floorToDouble();
    final stretch = math.sin(frac * math.pi);
    final width = slot * 0.66 * (1 + 0.55 * stretch);
    final height = 44 - 6 * stretch;
    final center = (rtl ? tabCount - 1 - page : page) * slot + slot / 2;

    return Positioned(
      left: center - width / 2,
      top: (_height - height) / 2,
      width: width,
      height: height,
      child: FloatingGlassHighlight(radius: height / 2),
    );
  }

  /// One tap target; the icon scales and tints toward [accent] as the
  /// highlight approaches it.
  Widget _tab(int index, double page, Color accent, Color textPrimary) {
    // 1 under the highlight, 0 one tab away.
    final t = (1 - (page - index).abs()).clamp(0.0, 1.0);
    return Semantics(
      button: true,
      label: _labels[index],
      selected: index == tabIndex.value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap(index);
        },
        child: Center(
          child: Transform.scale(
            scale: 1 + 0.18 * AppMotion.soft.transform(t),
            child: Icon(
              _icons[index],
              size: 25,
              color: Color.lerp(textPrimary.withValues(alpha: 0.38), accent, t),
            ),
          ),
        ),
      ),
    );
  }
}

/// Header bell. Unread dot and muted state come from NotificationService.
/// A long press mutes or unmutes.
class _NotificationsButton extends StatelessWidget {
  final VoidCallback onPressed;
  final VoidCallback onLongPress;

  const _NotificationsButton({
    required this.onPressed,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: NotificationService.instance,
      builder: (context, _) {
        final service = NotificationService.instance;
        final muted = service.isMuted;
        return GlassIconButton(
          icon: muted
              ? Icons.notifications_off_rounded
              : Icons.notifications_rounded,
          label: muted
              ? 'الإشعارات مكتومة. اضغط مطولاً لتفعيلها'
              : 'الإشعارات. اضغط مطولاً للكتم',
          onPressed: onPressed,
          onLongPress: onLongPress,
          dimmed: muted,
          showDot: service.unreadCount > 0,
        );
      },
    );
  }
}
