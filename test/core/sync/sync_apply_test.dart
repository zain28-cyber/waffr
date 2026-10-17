// applySyncResponse: an opened /sync reply is merged into every store with
// dirty marks suppressed, and acknowledged tombstones are dropped; plus the
// mute flag read from old and new settings payloads.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/sync/sync_apply.dart';
import 'package:waffr/core/sync/sync_dirty.dart';
import 'package:waffr/core/sync/sync_tombstones.dart';
import 'package:waffr/data/services/notification_service.dart';
import 'package:waffr/data/stores/category_store.dart';
import 'package:waffr/data/stores/expense_preset_store.dart';
import 'package:waffr/data/stores/recurring_expense_store.dart';
import 'package:waffr/data/stores/shopping_list_store.dart';
import 'package:waffr/data/stores/transaction_store.dart';

import '../../helpers/store_harness.dart';

const _stamp = '2026-01-05T00:00:00Z';

Map<String, dynamic> _section(List<Map<String, dynamic>> upserts) => {
  'upserts': upserts,
  'deletes': <Object>[],
};

void main() {
  setUp(() async {
    await setUpStores();
  });

  test('every collection reaches its store without marking dirty', () async {
    final ok = await applySyncResponse({
      'transactions': _section([
        {
          'client_id': 't1',
          'type': 'income',
          'amount': '500',
          'occurred_at': _stamp,
          'updated_at': _stamp,
        },
      ]),
      'savings_transfers': _section([
        {
          'client_id': 's1',
          'amount': '50',
          'direction': 'to_balance',
          'occurred_at': _stamp,
          'updated_at': _stamp,
        },
      ]),
      'savings_goals': _section([
        {
          'client_id': 'g1',
          'name': 'سفر',
          'target_amount': '900',
          'created_at': _stamp,
          'updated_at': _stamp,
        },
      ]),
      'expense_categories': _section([
        {
          'client_id': 'c1',
          'label': 'قهوة',
          'icon_index': 1,
          'updated_at': _stamp,
        },
      ]),
      'expense_presets': _section([
        {
          'client_id': 'p1',
          'amount': '5',
          'category': 'طعام',
          'created_at': _stamp,
          'updated_at': _stamp,
        },
      ]),
      'shopping_items': _section([
        {
          'client_id': 'i1',
          'name': 'خبز',
          'created_at': _stamp,
          'updated_at': _stamp,
        },
      ]),
      'recurring_expenses': _section([
        {
          'client_id': 'r1',
          'amount': '10',
          'category': 'فواتير',
          'unit': 'month',
          'interval_count': 1,
          'created_at': _stamp,
          'next_due_at': '2099-01-01T00:00:00Z',
          'updated_at': _stamp,
        },
      ]),
      'notifications': _section([
        {
          'client_id': 'n1',
          'type': 'goalReached',
          'title': 't',
          'message': 'm',
          'event_key': 'goalReached:g1',
          'created_at': _stamp,
          'updated_at': _stamp,
        },
      ]),
      'settings': {
        'notifications_muted': true,
        'updated_at': '2000-01-01T00:00:00Z',
      },
    });

    expect(ok, isTrue);
    expect(TransactionStore.instance.incomes.single.id, 't1');
    expect(
      TransactionStore.instance.savingsTransfers.single.isSavingsOut,
      isTrue,
    );
    expect(TransactionStore.instance.goals.single.id, 'g1');
    expect(CategoryStore.instance.entries.single.label, 'قهوة');
    expect(ExpensePresetStore.instance.items.single.id, 'p1');
    expect(ShoppingListStore.instance.items.single.name, 'خبز');
    expect(RecurringExpenseStore.instance.items.single.id, 'r1');
    expect(NotificationService.instance.notifications.single.id, 'n1');
    expect(NotificationService.instance.isMuted, isTrue);
    expect(await SyncDirty.isDirty(), isFalse);
    expect(SyncDirty.suppressed, isFalse, reason: 'restored afterwards');
  });

  test('sent and echoed tombstones are dropped, later ones kept', () async {
    final log = SyncTombstones.instance;
    await log.add(SyncCollection.transactions, 'sent');
    await log.add(SyncCollection.transactions, 'later');
    await log.add(SyncCollection.shoppingItems, 'echoed');

    final ok = await applySyncResponse(
      {
        'shopping_items': {
          'upserts': <Object>[],
          'deletes': [
            {'client_id': 'echoed', 'deleted_at': _stamp},
          ],
        },
      },
      sentTombstones: {
        'transactions': ['sent'],
      },
    );

    expect(ok, isTrue);
    expect(log.of(SyncCollection.transactions).map((t) => t.clientId), [
      'later',
    ]);
    expect(log.of(SyncCollection.shoppingItems), isEmpty);
  });

  test('missing or malformed sections are ignored', () async {
    expect(
      await applySyncResponse({
        'transactions': 'nope',
        'savings_goals': {'upserts': 'nope'},
        'settings': ['not a map'],
      }),
      isTrue,
    );
    expect(TransactionStore.instance.transactions, isEmpty);
  });

  test('mutedFromSyncSettings reads both payload versions', () {
    expect(mutedFromSyncSettings(null), isNull);
    expect(mutedFromSyncSettings('x'), isNull);
    expect(mutedFromSyncSettings({}), isNull);
    expect(mutedFromSyncSettings({'notifications_muted': true}), isTrue);
    expect(mutedFromSyncSettings({'notifications_muted': 'yes'}), isFalse);
    expect(mutedFromSyncSettings({'notifications_enabled': false}), isTrue);
    expect(mutedFromSyncSettings({'notifications_enabled': true}), isFalse);
    expect(
      mutedFromSyncSettings({
        'notifications_muted': false,
        'notifications_enabled': false,
      }),
      isFalse,
      reason: 'the newer key wins',
    );
  });
}
