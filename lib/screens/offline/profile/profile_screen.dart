// Profile tab: identity header, usage streak, usage duration, smart analysis
// button and usage counts, drawn over the breathing wallet backdrop whose
// mouth follows the financial health band. Account editing stays in Settings.

import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:waffr/widgets/motion/motion.dart';
import 'package:waffr/widgets/motion/active_listenable_builder.dart';
import 'package:waffr/screens/shell/app_shell_scope.dart';
import 'package:waffr/core/insights/profile_snapshot.dart';
import 'package:waffr/core/insights/smart/insight_engine.dart';
import 'package:waffr/core/insights/smart/smart_facts_loader.dart';
import 'package:waffr/core/theme/app_palette.dart';
import 'package:waffr/core/usage/usage_duration.dart';
import 'package:waffr/data/services/profile_identity.dart';
import 'package:waffr/data/services/usage_streak_service.dart';
import 'package:waffr/data/stores/currency_store.dart';
import 'package:waffr/data/stores/recurring_expense_store.dart';
import 'package:waffr/data/stores/transaction_store.dart';
import 'package:waffr/widgets/brand/profile_avatar.dart';
import 'package:waffr/screens/offline/profile/streak_card.dart';
import 'package:waffr/screens/offline/profile/wallet_backdrop.dart';
import 'package:waffr/widgets/containers/glass.dart';
import 'package:waffr/core/insights/smart/smart_insight.dart';
import 'package:waffr/widgets/smart/smart_analysis_button.dart';

/// The profile tab of the app shell. Kept alive; it only replays motion and
/// recomputes the health band while it is the visible tab.
class ProfileScreen extends StatefulWidget {
  /// The shell's selected tab; this screen is tab 4.
  final ValueNotifier<int> tabIndex;

  /// Creates a [ProfileScreen].
  const ProfileScreen({super.key, required this.tabIndex});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

/// State of [ProfileScreen]. Listens to the tab index and to the stores the
/// health score reads, and owns the coalescing health refresh timer.
class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  /// This screen's index in the shell's tab bar.
  static const int _tab = 4;

  final TransactionStore _store = TransactionStore.instance;

  /// Bumped each time the tab is reopened so the streak card plays again.
  int _streakReplay = 0;

  /// What the cards read from.
  late final Listenable _data = Listenable.merge([
    _store,
    CurrencyStore.instance,
    UsageStreakService.instance,
    ProfileIdentity.instance,
  ]);

  /// What the health score reads from.
  late final Listenable _healthData = Listenable.merge([
    _store,
    CurrencyStore.instance,
    RecurringExpenseStore.instance,
  ]);

  /// Band behind the wallet's smile; null until the first read.
  HealthBand? _health;

  /// Data changed since the last health read.
  bool _healthDirty = true;

  /// A health read is in flight; serializes reads.
  bool _healthLoading = false;

  /// Zero-delay timer that coalesces bursts of change notifications.
  Timer? _healthRefresh;

  /// Whether this tab is the one on screen.
  late bool _active = widget.tabIndex.value == _tab;

  /// False while an ancestor TickerMode disables animation (hidden page).
  bool _tickerEnabled = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.tabIndex.addListener(_onTab);
    _healthData.addListener(_queueHealth);
    _store.ensureLoaded();
    UsageStreakService.instance.ensureLoaded();
    ProfileIdentity.instance.reload();
    _queueHealth();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    if (_tickerEnabled) _queueHealth();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabIndex != widget.tabIndex) {
      oldWidget.tabIndex.removeListener(_onTab);
      widget.tabIndex.addListener(_onTab);
      _onTab();
    }
  }

  @override
  void dispose() {
    widget.tabIndex.removeListener(_onTab);
    _healthData.removeListener(_queueHealth);
    _healthRefresh?.cancel();
    super.dispose();
  }

  /// True after the user has gone to another tab. Coming back replays the
  /// streak card; the first arrival does not (the card already animates on
  /// its first build, so replaying then made it play twice).
  bool _leftTab = false;

  /// Tracks visibility; on return reloads the identity, replays the streak
  /// and refreshes health.
  void _onTab() {
    if (widget.tabIndex.value != _tab) {
      _leftTab = true;
      if (_active) setState(() => _active = false);
      return;
    }
    ProfileIdentity.instance.reload();
    final replay = _leftTab;
    _leftTab = false;
    setState(() {
      _active = true;
      if (replay) _streakReplay++;
    });
    _queueHealth();
  }

  /// Store hydration and a sync can emit several notifications together.
  /// Collapse those into one read and defer all health work on hidden tabs.
  void _queueHealth() {
    _healthDirty = true;
    if (!_active ||
        !_tickerEnabled ||
        _healthLoading ||
        _healthRefresh?.isActive == true) {
      return;
    }
    _healthRefresh = Timer(Duration.zero, _readHealth);
  }

  /// Same score as the smart analysis. With nothing logged yet the wallet
  /// keeps the logo's own smile. A result is dropped if data changed while
  /// it loaded; the finally block then queues a fresh read.
  Future<void> _readHealth() async {
    if (!mounted ||
        !_active ||
        !_tickerEnabled ||
        _healthLoading ||
        !_healthDirty) {
      return;
    }
    _healthDirty = false;
    _healthLoading = true;
    try {
      final facts = await SmartFactsLoader.load();
      if (!mounted || !_active || !_tickerEnabled || _healthDirty) return;
      final empty =
          facts.expenses.isEmpty &&
          facts.incomes.isEmpty &&
          facts.savingsTransfers.isEmpty;
      final band = empty
          ? HealthBand.excellent
          : HealthBand.of(InsightEngine(facts).healthScore());
      if (band != _health) setState(() => _health = band);
    } finally {
      _healthLoading = false;
      if (mounted && _active && _tickerEnabled && _healthDirty) _queueHealth();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final palette = AppPalette.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final page = constraints.biggest;
        final bottom = math.max(
          kFloatingNavClearance,
          WalletBackdrop.contentClearance(page),
        );

        // The wallet hangs from the bottom of the content, which is at least
        // a page tall, so its smile lands just below the stats and the cards
        // are painted over the rest of it.
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: page.height),
            child: Stack(
              children: [
                Positioned.fill(
                  child: WalletBackdrop(
                    page: page,
                    band: _health,
                    active: _active,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(18, 18, 18, bottom),
                  child: _cards(palette),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Foreground cards: header, streak, duration + smart button, stats.
  Widget _cards(AppPalette palette) {
    return ActiveListenableBuilder(
      listenable: _data,
      builder: (context, _) {
        final snapshot = ProfileSnapshot.fromStore(_store);
        final streak = UsageStreakService.instance;
        final identity = ProfileIdentity.instance;
        final started = streak.startedAt;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: staggered([
            _ProfileHeader(identity: identity, palette: palette),
            const SizedBox(height: kCardGap),
            StreakCard(
              count: streak.isLoaded && streak.count > 0 ? streak.count : 1,
              lastDay: streak.lastDay,
              replayToken: _streakReplay,
            ),
            const SizedBox(height: kCardGap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: started == null
                      ? const SizedBox.shrink()
                      : _UsageDuration(
                          text: usageDurationText(started, DateTime.now()),
                          palette: palette,
                        ),
                ),
                const SizedBox(width: 8),
                const SmartAnalysisButton(
                  scope: InsightScope.profile,
                  large: true,
                ),
              ],
            ),
            const SizedBox(height: kCardGap),
            _UsageStats(snapshot: snapshot, palette: palette),
          ]),
        );
      },
    );
  }
}

/// Avatar with display name and, when signed in, the email.
class _ProfileHeader extends StatelessWidget {
  final ProfileIdentity identity;
  final AppPalette palette;

  const _ProfileHeader({required this.identity, required this.palette});

  @override
  Widget build(BuildContext context) {
    final email = identity.displayEmail;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileAvatar(
            accent: palette.accent,
            radius: 46,
            signedIn: identity.isLoggedIn,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: SizedBox(
              height: 92,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    identity.displayName,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontFamilyFallback: const ['Tajawal'],
                      fontSize: 28,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      color: palette.textPrimary,
                    ),
                  ),
                  if (email != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      email,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontFamilyFallback: const ['Tajawal'],
                        fontSize: 15,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Usage duration" caption over how long the app has been used.
class _UsageDuration extends StatelessWidget {
  final String text;
  final AppPalette palette;

  const _UsageDuration({required this.text, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'مدة الاستخدام',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontFamilyFallback: const ['Tajawal'],
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          text,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontFamilyFallback: const ['Tajawal'],
            fontSize: 26,
            height: 1.1,
            fontWeight: FontWeight.w800,
            color: palette.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Four count tiles: expenses, incomes, goals and savings moves.
class _UsageStats extends StatelessWidget {
  final ProfileSnapshot snapshot;
  final AppPalette palette;

  const _UsageStats({required this.snapshot, required this.palette});

  @override
  Widget build(BuildContext context) {
    const gap = 6.0;
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            value: snapshot.expenseCount,
            label: 'عمليات الصرف',
            palette: palette,
          ),
        ),
        const SizedBox(width: gap),
        Expanded(
          child: _StatTile(
            value: snapshot.incomeCount,
            label: 'عمليات الدخل',
            palette: palette,
          ),
        ),
        const SizedBox(width: gap),
        Expanded(
          child: _StatTile(
            value: snapshot.goalCount,
            label: 'أهداف التوفير',
            palette: palette,
          ),
        ),
        const SizedBox(width: gap),
        Expanded(
          child: _StatTile(
            value: snapshot.savingsCount,
            label: 'عمليات التوفير',
            palette: palette,
          ),
        ),
      ],
    );
  }
}

/// One count with its label in a glass tile.
class _StatTile extends StatelessWidget {
  final int value;
  final String label;
  final AppPalette palette;

  const _StatTile({
    required this.value,
    required this.label,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      colorType: GlassColorType.surface,
      borderRadius: 18,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontFamilyFallback: const ['Tajawal'],
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: palette.accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontFamilyFallback: const ['Tajawal'],
              fontSize: 10.5,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
