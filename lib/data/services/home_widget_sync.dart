// Keeps the home screen widgets current. Text is formatted here, in
// Arabic and in the active currency, so the native widgets only display it.
// Native code: android/app/src/main/kotlin/com/waffr/app/widgets and
// ios/WaffrWidgets.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:waffr/core/insights/smart/arabic_text.dart';
import 'package:waffr/core/sync/sync_clock.dart';
import 'package:waffr/core/usage/streak_math.dart';
import 'package:waffr/core/utils/money.dart';
import 'package:waffr/data/services/usage_streak_service.dart';
import 'package:waffr/data/stores/currency_store.dart';
import 'package:waffr/data/stores/recurring_expense_store.dart';
import 'package:waffr/data/stores/transaction_store.dart';
import 'package:waffr/core/utils/calendar_days.dart';

/// Writes the figures the home screen widgets show and asks them to redraw.
class HomeWidgetSync {
  HomeWidgetSync._();

  /// The app-wide service.
  static final HomeWidgetSync instance = HomeWidgetSync._();

  /// Shared with the iOS widget extension (App Groups capability).
  static const String appGroupId = 'group.com.waffr.app';

  static const List<({String android, String ios})> _widgets = [
    (
      android: 'com.waffr.app.widgets.BalanceWidgetProvider',
      ios: 'WaffrBalanceWidget',
    ),
    (
      android: 'com.waffr.app.widgets.QuickAddWidgetProvider',
      ios: 'WaffrQuickAddWidget',
    ),
    (
      android: 'com.waffr.app.widgets.GoalWidgetProvider',
      ios: 'WaffrGoalWidget',
    ),
    (
      android: 'com.waffr.app.widgets.ObligationWidgetProvider',
      ios: 'WaffrObligationWidget',
    ),
    (
      android: 'com.waffr.app.widgets.StreakWidgetProvider',
      ios: 'WaffrStreakWidget',
    ),
  ];

  bool _started = false;
  Timer? _debounce;

  /// True on Android and iOS, the platforms with widgets.
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Starts following the stores; later changes refresh the widgets.
  Future<void> start() async {
    if (_started || !supported) return;
    _started = true;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await HomeWidget.setAppGroupId(appGroupId);
      }
    } on PlatformException {
      // No widget extension configured yet; data still saves on Android.
    } on MissingPluginException {
      return;
    }
    for (final source in <Listenable>[
      TransactionStore.instance,
      RecurringExpenseStore.instance,
      CurrencyStore.instance,
      UsageStreakService.instance,
    ]) {
      source.addListener(_schedule);
    }
    await refresh();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), refresh);
  }

  /// Saves fresh widget data and redraws every widget; errors are ignored.
  Future<void> refresh() async {
    if (!supported) return;
    try {
      final data = await _snapshot();
      for (final entry in data.entries) {
        await HomeWidget.saveWidgetData<Object>(entry.key, entry.value);
      }
      for (final widget in _widgets) {
        await HomeWidget.updateWidget(
          qualifiedAndroidName: widget.android,
          iOSName: widget.ios,
        );
      }
    } on PlatformException {
      // A widget kind that is not installed is not an error worth surfacing.
    } on MissingPluginException {
      // Tests and unsupported hosts.
    }
  }

  Future<Map<String, Object>> _snapshot() async {
    final store = TransactionStore.instance;
    final recurring = RecurringExpenseStore.instance;
    final streak = UsageStreakService.instance;
    await Future.wait([
      store.ensureLoaded(),
      recurring.ensureLoaded(),
      streak.ensureLoaded(),
    ]);
    return buildHomeWidgetData(
      now: deviceNow(),
      symbol: CurrencyStore.instance.activeSymbol,
      balance: store.balance,
      spent: store.cycleSpent,
      maxBalance: store.maxBalance,
      remainingRatio: store.remainingRatio,
      goal: store.activeGoals.isEmpty
          ? null
          : (
              name: store.activeGoals.first.name,
              target: store.activeGoals.first.targetAmount,
              saved: store.goalProgress(store.activeGoals.first),
            ),
      obligations: [
        for (final item in recurring.itemsFor(
          CurrencyStore.instance.activeCode,
        ))
          if (item.enabled)
            (
              name: item.note?.trim().isNotEmpty == true
                  ? item.note!.trim()
                  : item.category,
              amount: item.amount,
              due: item.nextDueAt,
            ),
      ],
      streak: streak.count,
      streakLastDay: streak.lastDay,
    );
  }
}

/// The text every widget shows, keyed as the native widgets read it.
@visibleForTesting
Map<String, Object> buildHomeWidgetData({
  required DateTime now,
  required String symbol,
  required double balance,
  required double spent,
  required double maxBalance,
  required double remainingRatio,
  required ({String name, double target, double saved})? goal,
  required List<({String name, double amount, DateTime due})> obligations,
  required int streak,
  DateTime? streakLastDay,
}) {
  final remaining = (remainingRatio * 100).round().clamp(0, 100);
  final data = <String, Object>{
    'balance_amount': formatMoney(balance),
    'balance_currency': symbol,
    'balance_percent': '$remaining',
    'balance_percent_label': 'المتبقي \u2066$remaining%\u2069',
    'balance_caption':
        'مصروف ${formatMoney(spent)} من ${formatMoney(maxBalance)} $symbol',
  };

  if (goal == null || goal.target <= 0) {
    data['goal_empty'] = true;
    data['goal_name'] = 'لا يوجد هدف بعد';
    data['goal_caption'] = 'اضغط لإنشاء هدفك الأول';
    data['goal_percent'] = '0';
    data['goal_percent_label'] = '';
  } else {
    final percent = (goal.saved / goal.target * 100).round().clamp(0, 100);
    data['goal_empty'] = false;
    data['goal_name'] = goal.name;
    data['goal_percent'] = '$percent';
    data['goal_percent_label'] = '\u2066$percent%\u2069';
    data['goal_caption'] =
        'تم توفير ${formatMoney(goal.saved)} من ${formatMoney(goal.target)} $symbol';
  }

  final today = DateTime(now.year, now.month, now.day);
  final upcoming = [...obligations]..sort((a, b) => a.due.compareTo(b.due));
  if (upcoming.isEmpty) {
    data['obligation_empty'] = true;
    data['obligation_name'] = 'لا توجد التزامات قادمة';
    data['obligation_amount'] = '';
    data['obligation_value'] = '';
    data['obligation_when'] = '';
  } else {
    final next = upcoming.first;
    final dueDay = DateTime(next.due.year, next.due.month, next.due.day);
    final days = calendarDaysBetween(today, dueDay);
    data['obligation_empty'] = false;
    data['obligation_name'] = next.name;
    data['obligation_amount'] = '${formatMoney(next.amount)} $symbol';
    data['obligation_value'] = formatMoney(next.amount);
    data['obligation_when'] = switch (days) {
      < 0 => 'مستحق الآن',
      0 => 'اليوم',
      1 => 'غداً',
      _ => 'بعد ${Ar.days.of(days)}',
    };
  }

  final count = streak < 1 ? 1 : streak;
  data['streak_count'] = '$count';
  // The widget is not redrawn by the app on days it stays closed, so it
  // checks this date itself: past it, a whole day was skipped and the
  // streak shows as broken.
  if (streakLastDay != null) {
    final aliveUntil = DateTime(
      streakLastDay.year,
      streakLastDay.month,
      streakLastDay.day + 1,
    );
    data['streak_alive_until'] = StreakSnapshot.dayKey(aliveUntil)!;
  }
  data['streak_reset_label'] = 'ابدأ من جديد';
  // The ring fills toward the next milestone, as on the profile card.
  data['streak_percent'] =
      '${(count / nextStreakMilestone(count) * 100).round().clamp(0, 100)}';
  data['streak_word'] = switch (count) {
    1 => 'يوم',
    <= 10 => 'أيام',
    _ => 'يوماً',
  };
  data['streak_label'] = switch (count) {
    1 => 'اليوم الأول',
    2 => 'يومان متتاليان',
    >= 3 && <= 10 => 'أيام متتالية',
    _ => 'يوماً متتالياً',
  };
  return data;
}
