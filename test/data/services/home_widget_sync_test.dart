// HomeWidgetSync: the widget text built by buildHomeWidgetData, and
// refresh() writing the live store figures through a mocked home_widget
// method channel.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/data/models/savings_goal.dart';
import 'package:waffr/data/stores/transaction_store.dart';
import 'package:waffr/data/services/home_widget_sync.dart';

import '../../helpers/store_harness.dart';

void main() {
  final now = DateTime(2026, 10, 20, 9);

  Map<String, Object> build({
    ({String name, double target, double saved})? goal,
    List<({String name, double amount, DateTime due})> obligations = const [],
    int streak = 5,
  }) => buildHomeWidgetData(
    now: now,
    symbol: 'ل.س',
    balance: 400,
    spent: 600,
    maxBalance: 1000,
    remainingRatio: 0.4,
    goal: goal,
    obligations: obligations,
    streak: streak,
  );

  test('balance text and remaining percent', () {
    final data = build();

    expect(data['balance_amount'], '400');
    expect(data['balance_percent'], '40');
    expect(data['balance_caption'], 'مصروف 600 من 1,000 ل.س');
  });

  test('empty goal and obligation fall back to friendly text', () {
    final data = build();

    expect(data['goal_empty'], true);
    expect(data['obligation_empty'], true);
  });

  test('nearest obligation wins and its date reads naturally', () {
    final data = build(
      obligations: [
        (name: 'إنترنت', amount: 50, due: DateTime(2026, 10, 25)),
        (name: 'إيجار', amount: 300, due: DateTime(2026, 10, 21)),
      ],
    );

    expect(data['obligation_name'], 'إيجار');
    expect(data['obligation_when'], 'غداً');
    expect(
      build(
        obligations: [(name: 'x', amount: 1, due: DateTime(2026, 10, 25))],
      )['obligation_when'],
      'بعد 5 أيام',
    );
  });

  test('goal percent and streak label agree with the number', () {
    final data = build(
      goal: (name: 'سفر', target: 1000, saved: 250),
      streak: 12,
    );

    expect(data['goal_percent'], '25');
    expect(data['goal_empty'], false);
    expect(data['streak_label'], 'يوماً متتالياً');
    expect(build(streak: 4)['streak_label'], 'أيام متتالية');
    expect(data['streak_word'], 'يوماً');
    expect(data['streak_percent'], '86'); // 12 of 14
    expect(build(streak: 1)['streak_word'], 'يوم');
  });

  test('the streak widget learns the last day it stays alive', () {
    final data = buildHomeWidgetData(
      now: now,
      symbol: 'ل.س',
      balance: 0,
      spent: 0,
      maxBalance: 0,
      remainingRatio: 0,
      goal: null,
      obligations: const [],
      streak: 3,
      streakLastDay: DateTime(2026, 10, 31),
    );

    expect(data['streak_alive_until'], '2026-11-01');
    expect(data['streak_reset_label'], 'ابدأ من جديد');
    expect(build().containsKey('streak_alive_until'), isFalse);
  });

  group('refresh', () {
    const channel = MethodChannel('home_widget');
    late Map<String, Object?> saved;
    late List<String?> updated;

    setUp(() async {
      await setUpStores();
      saved = {};
      updated = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            final args = (call.arguments as Map).cast<String, Object?>();
            if (call.method == 'saveWidgetData') {
              saved[args['id']! as String] = args['data'];
            } else if (call.method == 'updateWidget') {
              updated.add(args['qualifiedAndroidName'] as String?);
            }
            return true;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('writes the live balance and goal and redraws every widget', () async {
      final store = TransactionStore.instance;
      await store.addIncome(amount: 1000);
      await store.addExpense(
        amount: 250,
        category: 'طعام',
        paymentMethod: 'نقداً',
      );
      await store.createGoal(
        name: 'سفر',
        targetAmount: 1000,
        duration: GoalDurationPreset.year,
      );
      await store.saveManually(100);

      await HomeWidgetSync.instance.refresh();

      expect(saved['balance_amount'], '650');
      expect(saved['balance_currency'], 'ل.س');
      expect(saved['goal_name'], 'سفر');
      expect(saved['goal_percent'], '10');
      expect(saved['obligation_empty'], true);
      expect(updated, hasLength(5));
      expect(updated, contains('com.waffr.app.widgets.BalanceWidgetProvider'));
    });

    test('a missing plugin is ignored', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      await expectLater(HomeWidgetSync.instance.refresh(), completes);
    });
  });

  test('a goal with no target and an overdue obligation', () {
    final data = buildHomeWidgetData(
      now: now,
      symbol: r'$',
      balance: 0,
      spent: 0,
      maxBalance: 0,
      remainingRatio: 1.7,
      goal: (name: 'x', target: 0, saved: 5),
      obligations: [(name: 'y', amount: 9, due: DateTime(2026, 10, 1))],
      streak: 0,
    );
    expect(data['balance_percent'], '100');
    expect(data['goal_empty'], true);
    expect(data['obligation_when'], 'مستحق الآن');
    expect(data['obligation_amount'], r'9 $');
    expect(data['streak_count'], '1');
    expect(data['streak_label'], 'اليوم الأول');
    expect(data['streak_word'], 'يوم');
  });

  test('today and two-day streak wording', () {
    final data = buildHomeWidgetData(
      now: now,
      symbol: 'ل.س',
      balance: 0,
      spent: 0,
      maxBalance: 0,
      remainingRatio: 0,
      goal: null,
      obligations: [(name: 'y', amount: 9, due: DateTime(2026, 10, 20, 23))],
      streak: 2,
    );
    expect(data['obligation_when'], 'اليوم');
    expect(data['streak_label'], 'يومان متتاليان');
    expect(data['streak_word'], 'أيام');
    expect(data['streak_percent'], '67');
  });
}
