// mergeRemoteRecords: last-write-wins upserts (strictly newer only), server
// deletes against the local row time, local tombstones blocking old rows,
// appends, and the change flag.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/sync/sync_merge.dart';
import 'package:waffr/core/sync/sync_tombstones.dart';

import '../../helpers/store_harness.dart';

typedef _Row = ({String id, int version, DateTime updated});

_Row _row(String id, int version, int day) =>
    (id: id, version: version, updated: DateTime.utc(2026, 1, day));

bool _merge(
  List<_Row> items, {
  List<_Row> upserts = const [],
  List<SyncTombstone> deletes = const [],
}) => mergeRemoteRecords<_Row>(
  items: items,
  upserts: upserts,
  deletes: deletes,
  collection: SyncCollection.transactions,
  idOf: (row) => row.id,
  updatedOf: (row) => row.updated,
);

void main() {
  setUp(() async {
    await setUpStores();
    await SyncTombstones.instance.ensureLoaded();
  });

  test('new rows are appended in order', () {
    final items = [_row('a', 1, 1)];
    expect(_merge(items, upserts: [_row('b', 1, 2), _row('c', 1, 3)]), isTrue);
    expect(items.map((r) => r.id), ['a', 'b', 'c']);
  });

  test('a strictly newer row replaces in place; equal or older does not', () {
    final items = [_row('a', 1, 5), _row('b', 1, 5)];
    expect(_merge(items, upserts: [_row('b', 2, 5)]), isFalse);
    expect(_merge(items, upserts: [_row('b', 2, 4)]), isFalse);
    expect(items[1].version, 1);

    expect(_merge(items, upserts: [_row('b', 3, 6)]), isTrue);
    expect(items.map((r) => r.id), ['a', 'b']);
    expect(items[1].version, 3);
  });

  test('a later duplicate in the same batch wins only if newer', () {
    final items = <_Row>[];
    _merge(items, upserts: [_row('a', 1, 2), _row('a', 2, 1), _row('a', 3, 3)]);
    expect(items.single.version, 3);
  });

  test('deletes need to be at least as new as the local row', () {
    final items = [_row('a', 1, 5), _row('b', 1, 5)];
    expect(
      _merge(
        items,
        deletes: [
          SyncTombstone(clientId: 'a', deletedAt: DateTime.utc(2026, 1, 4)),
          SyncTombstone(clientId: 'missing', deletedAt: DateTime.utc(2027)),
        ],
      ),
      isFalse,
    );
    expect(
      _merge(
        items,
        deletes: [
          SyncTombstone(clientId: 'b', deletedAt: DateTime.utc(2026, 1, 5)),
        ],
      ),
      isTrue,
    );
    expect(items.map((r) => r.id), ['a']);
  });

  test('deletes run before upserts in one merge', () {
    final items = [_row('a', 1, 1)];
    _merge(
      items,
      deletes: [
        SyncTombstone(clientId: 'a', deletedAt: DateTime.utc(2026, 1, 2)),
      ],
      upserts: [_row('a', 2, 3)],
    );
    expect(items.single.version, 2, reason: 'a newer row comes back');
  });

  test('a local tombstone blocks rows not newer than the delete', () async {
    await SyncTombstones.instance.add(SyncCollection.transactions, 'gone');
    final items = <_Row>[];
    expect(_merge(items, upserts: [_row('gone', 1, 1)]), isFalse);
    expect(items, isEmpty);

    final future = (
      id: 'gone',
      version: 2,
      updated: DateTime.now().toUtc().add(const Duration(days: 1)),
    );
    expect(_merge(items, upserts: [future]), isTrue);
  });

  test('tombstones are per collection', () async {
    await SyncTombstones.instance.add(SyncCollection.notifications, 'x');
    final items = <_Row>[];
    expect(_merge(items, upserts: [_row('x', 1, 1)]), isTrue);
  });
}
