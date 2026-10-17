// SyncTombstones: the persisted delete log per collection (add, addMany,
// find, remove, clearAll, reload from prefs, bad JSON) and the
// SyncTombstone wire shape.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/sync/sync_tombstones.dart';

import '../../helpers/store_harness.dart';

void main() {
  final log = SyncTombstones.instance;

  setUp(() async {
    await setUpStores();
  });

  group('SyncTombstone', () {
    test('wire shape and decode in either case', () {
      final tomb = SyncTombstone(
        clientId: 'a',
        deletedAt: DateTime.utc(2026, 2, 3),
      );
      expect(tomb.toJson(), {
        'client_id': 'a',
        'deleted_at': '2026-02-03T00:00:00.000Z',
      });
      final back = SyncTombstone.decode(tomb.toJson())!;
      expect(back.clientId, 'a');
      expect(back.deletedAt, DateTime.utc(2026, 2, 3));

      final camel = SyncTombstone.decode({
        'clientId': ' b ',
        'deletedAt': '2026-01-01T00:00:00Z',
      })!;
      expect(camel.clientId, 'b');
    });

    test('decode rejects non-maps and blank ids; bad dates become now', () {
      expect(SyncTombstone.decode('a'), isNull);
      expect(SyncTombstone.decode({'client_id': '  '}), isNull);
      final before = DateTime.now().toUtc();
      final noDate = SyncTombstone.decode({'client_id': 'x'})!;
      expect(noDate.deletedAt.isBefore(before), isFalse);
    });
  });

  test('add, find and snapshot per collection', () async {
    await log.add(SyncCollection.transactions, ' t1 ');
    await log.add(SyncCollection.transactions, '');
    await log.add(SyncCollection.savingsGoals, 'g1');

    expect(log.of(SyncCollection.transactions).map((t) => t.clientId), ['t1']);
    expect(log.find(SyncCollection.transactions, 't1'), isNotNull);
    expect(log.find(SyncCollection.transactions, 'g1'), isNull);
    expect(log.of(SyncCollection.notifications), isEmpty);
    expect(
      () => log
          .of(SyncCollection.transactions)
          .add(SyncTombstone(clientId: 'x', deletedAt: DateTime.utc(2026))),
      throwsUnsupportedError,
    );
  });

  test('re-adding an id refreshes its delete time', () async {
    await log.add(SyncCollection.transactions, 'a');
    final first = log.find(SyncCollection.transactions, 'a')!.deletedAt;
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await log.add(SyncCollection.transactions, 'a');
    expect(log.of(SyncCollection.transactions), hasLength(1));
    expect(
      log.find(SyncCollection.transactions, 'a')!.deletedAt.isAfter(first),
      isTrue,
    );
  });

  test('addMany shares one time and skips blanks', () async {
    await log.addMany(SyncCollection.shoppingItems, ['a', ' ', 'b']);
    final items = log.of(SyncCollection.shoppingItems);
    expect(items.map((t) => t.clientId), ['a', 'b']);
    expect(items[0].deletedAt, items[1].deletedAt);
  });

  test('remove and clearAll', () async {
    await log.addMany(SyncCollection.notifications, ['a', 'b', 'c']);
    await log.add(SyncCollection.transactions, 't');
    await log.remove(SyncCollection.notifications, ['a', 'missing']);
    expect(log.of(SyncCollection.notifications).map((t) => t.clientId), [
      'b',
      'c',
    ]);
    await log.clearAll();
    for (final collection in SyncCollection.values) {
      expect(log.of(collection), isEmpty);
    }
  });

  test('the log survives a reload', () async {
    await log.add(SyncCollection.expensePresets, 'p1');
    await log.add(SyncCollection.expenseCategories, 'c1');
    log.resetCache();
    expect(log.of(SyncCollection.expensePresets), isEmpty);
    await log.ensureLoaded();
    expect(log.find(SyncCollection.expensePresets, 'p1'), isNotNull);
    expect(log.find(SyncCollection.expenseCategories, 'c1'), isNotNull);
  });

  test('stored JSON is read leniently', () async {
    final prefs = await setUpStores();
    await prefs.setString(
      'waffer_sync_tombstones',
      jsonEncode({
        'transactions': [
          {'client_id': 'ok', 'deleted_at': '2026-01-01T00:00:00Z'},
          {'client_id': ''},
          'junk',
        ],
        'savingsGoals': 'not a list',
        'unknownCollection': [
          {'client_id': 'x'},
        ],
      }),
    );
    log.resetCache();
    await log.ensureLoaded();
    expect(log.of(SyncCollection.transactions).single.clientId, 'ok');
    expect(log.of(SyncCollection.savingsGoals), isEmpty);

    await prefs.setString('waffer_sync_tombstones', '{broken');
    log.resetCache();
    await log.ensureLoaded();
    expect(log.of(SyncCollection.transactions), isEmpty);
  });
}
