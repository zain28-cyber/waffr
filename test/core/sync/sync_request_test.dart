// buildSyncRequest / syncSettingsPayload / tombstoneIdsIn: the plain push
// body built from every store, the lastSync filter, tombstones, the default
// shopping list row and the settings block.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/sync/sync_dirty.dart';
import 'package:waffr/core/sync/sync_mapper.dart';
import 'package:waffr/core/sync/sync_request.dart';
import 'package:waffr/data/models/app_notification.dart';
import 'package:waffr/data/models/expense_preset.dart';
import 'package:waffr/data/models/recurring_expense.dart';
import 'package:waffr/data/models/savings_goal.dart';
import 'package:waffr/data/models/transaction.dart';
import 'package:waffr/data/services/notification_service.dart';
import 'package:waffr/data/stores/category_store.dart';
import 'package:waffr/data/stores/currency_store.dart';
import 'package:waffr/data/stores/expense_preset_store.dart';
import 'package:waffr/data/stores/recurring_expense_store.dart';
import 'package:waffr/data/stores/shopping_list_store.dart';
import 'package:waffr/data/stores/transaction_store.dart';

import '../../helpers/store_harness.dart';

const _sections = [
  'transactions',
  'savings_goals',
  'savings_transfers',
  'shopping_lists',
  'shopping_items',
  'recurring_expenses',
  'notifications',
  'expense_categories',
  'expense_presets',
];

List<Map<String, dynamic>> _upserts(Map<String, dynamic> body, String key) =>
    (body[key]['upserts'] as List).cast<Map<String, dynamic>>();

List _deletes(Map<String, dynamic> body, String key) =>
    body[key]['deletes'] as List;

void main() {
  setUp(() async {
    await setUpStores();
  });

  Future<void> fillEveryStore() async {
    final ledger = TransactionStore.instance;
    await ledger.addIncome(amount: 1000, frequency: RecurringFrequency.monthly);
    await ledger.addExpense(
      amount: 50,
      category: 'طعام',
      paymentMethod: 'نقداً',
    );
    await ledger.createGoal(
      name: 'سفر',
      targetAmount: 5000,
      duration: GoalDurationPreset.year,
    );
    await ledger.saveManually(100);
    await ShoppingListStore.instance.addItem('خبز');
    await RecurringExpenseStore.instance.addExpense(
      amount: 10,
      category: 'فواتير',
      paymentMethod: 'نقداً',
      unit: RecurringUnit.month,
      intervalCount: 1,
    );
    await NotificationService.instance.add(
      type: NotificationType.goalReached,
      title: 't',
      message: 'm',
      eventKey: 'k',
    );
    await CategoryStore.instance.addCustom('قهوة');
    await ExpensePresetStore.instance.add(
      ExpensePreset(
        id: 'p1',
        amount: 5,
        category: 'طعام',
        paymentMethod: 'نقداً',
        createdAt: DateTime.now(),
      ),
    );
  }

  test(
    'an empty first sync sends empty sections, the list and settings',
    () async {
      final body = await buildSyncRequest(lastSync: null, everyRow: false);
      expect(body['last_sync_at'], isNull);
      for (final key in _sections) {
        expect(body[key], isA<Map>(), reason: key);
        expect(_deletes(body, key), isEmpty);
      }
      expect(_upserts(body, 'transactions'), isEmpty);
      expect(
        _upserts(body, 'shopping_lists').single['client_id'],
        defaultShoppingListId,
      );
      expect(body['settings'], isA<Map>());
    },
  );

  test('every store contributes its rows', () async {
    await fillEveryStore();
    final body = await buildSyncRequest(lastSync: null, everyRow: true);

    final transactions = _upserts(body, 'transactions');
    // The recurring bill posts its first charge right away.
    expect(
      transactions.map((r) => r['type']),
      unorderedEquals(['income', 'expense', 'expense']),
    );
    expect(
      _upserts(body, 'savings_transfers').single['direction'],
      'to_savings',
    );
    expect(_upserts(body, 'savings_goals').single['name'], 'سفر');
    expect(_upserts(body, 'shopping_items').single['name'], 'خبز');
    expect(_upserts(body, 'recurring_expenses').single['amount'], '10.0');
    expect(_upserts(body, 'notifications'), isNotEmpty);
    expect(_upserts(body, 'expense_categories').single['label'], 'قهوة');
    expect(_upserts(body, 'expense_presets').single['client_id'], 'p1');
  });

  test('without everyRow only rows changed since lastSync go out', () async {
    await fillEveryStore();
    final future = DateTime.now().toUtc().add(const Duration(days: 1));
    await SyncDirty.setSettingsUpdatedAt(DateTime.utc(2020));

    final body = await buildSyncRequest(lastSync: future, everyRow: false);
    expect(body['last_sync_at'], toSyncIsoForTest(future));
    for (final key in _sections) {
      expect(_upserts(body, key), isEmpty, reason: key);
    }
    expect(body['settings'], isNull);

    final full = await buildSyncRequest(lastSync: future, everyRow: true);
    expect(_upserts(full, 'transactions'), hasLength(3));
    expect(_upserts(full, 'shopping_lists'), hasLength(1));
    expect(full['settings'], isA<Map>());
  });

  test('settings go out when they changed after the last sync', () async {
    final past = DateTime.utc(2020);
    await SyncDirty.mark(settings: true);
    final body = await buildSyncRequest(lastSync: past, everyRow: false);
    expect(body['settings'], isA<Map>());
  });

  test('tombstones always go out', () async {
    await TransactionStore.instance.addIncome(amount: 100);
    final id = TransactionStore.instance.incomes.single.id;
    await TransactionStore.instance.undoIncome(id);
    final body = await buildSyncRequest(
      lastSync: DateTime.now().toUtc().add(const Duration(days: 1)),
      everyRow: false,
    );
    expect(_deletes(body, 'transactions').single['client_id'], id);
    expect(tombstoneIdsIn(body)['transactions'], [id]);
    expect(tombstoneIdsIn(body)['notifications'], isEmpty);
  });

  test('the settings block reflects every store', () async {
    final prefs = await setUpStores();
    await prefs.setString('user_name', 'سارة');
    await prefs.setBool('dark_mode', true);
    await TransactionStore.instance.setPreferredIncomeAmount(
      frequency: RecurringFrequency.monthly,
      amount: 1200,
    );
    await TransactionStore.instance.setPreferredIncomeAmount(
      frequency: RecurringFrequency.weekly,
      amount: 40,
      currencyCode: 'USD',
    );
    await CurrencyStore.instance.addCurrency('USD');
    await CategoryStore.instance.removeCategory('صحة');
    await NotificationService.instance.setMuted(true);

    final settings = await syncSettingsPayload();
    expect(settings['notifications_muted'], isTrue);
    expect(settings['notifications_enabled'], isFalse);
    expect(settings['monthly_income_amount'], 1200);
    expect(settings['weekly_income_amount'], isNull);
    expect(settings['income_overrides_by_currency'], {
      'USD': {'weekly': 40.0},
    });
    expect(settings['enabled_currencies'], ['SYP', 'USD']);
    expect(settings['active_currency'], 'SYP');
    expect(settings['hidden_categories'], ['صحة']);
    expect(settings['display_name'], 'سارة');
    expect(settings['dark_mode'], isTrue);
    expect(settings['processed_period_keys'], isEmpty);
    expect(settings['updated_at'], isA<String>());
  });

  test('tombstoneIdsIn skips sections without a deletes list', () {
    expect(
      tombstoneIdsIn({
        'last_sync_at': null,
        'settings': {'a': 1},
        'x': {
          'deletes': [
            {'client_id': 'a'},
            {'other': 1},
            'junk',
          ],
        },
      }),
      {
        'x': ['a'],
      },
    );
  });
}

/// The ISO text the request uses for [value].
String toSyncIsoForTest(DateTime value) => value.toUtc().toIso8601String();
