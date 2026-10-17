// SyncSentRows: the in-memory record of row fingerprints the server holds
// (incremental vs full pushes, forgetting deleted ids, defensive copies).

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/sync/sync_sent_rows.dart';

void main() {
  test('starts empty', () {
    final rows = SyncSentRows();
    expect(rows.isEmpty, isTrue);
    expect(rows.known, isEmpty);
  });

  test('an incremental push adds to what is known', () {
    final rows = SyncSentRows()
      ..remember({
        'transactions': {'a': '1'},
      }, replace: true)
      ..remember({
        'transactions': {'b': '2', 'a': '3'},
        'notifications': {'n': '4'},
      }, replace: false);
    expect(rows.known, {
      'transactions': {'a': '3', 'b': '2'},
      'notifications': {'n': '4'},
    });
    expect(rows.isEmpty, isFalse);
  });

  test('empty collections still count as empty', () {
    final rows = SyncSentRows()..remember({'transactions': {}}, replace: true);
    expect(rows.isEmpty, isTrue);
  });

  test('deleted ids in unknown collections are ignored', () {
    final rows = SyncSentRows()
      ..remember(
        {
          'transactions': {'a': '1'},
        },
        replace: true,
        deleted: {
          'savings_goals': ['g'],
          'transactions': ['missing'],
        },
      );
    expect(rows.known, {
      'transactions': {'a': '1'},
    });
  });

  test('known is a copy', () {
    final rows = SyncSentRows()
      ..remember({
        'transactions': {'a': '1'},
      }, replace: true);
    rows.known['transactions']!['a'] = 'changed';
    rows.known.remove('transactions');
    expect(rows.known['transactions'], {'a': '1'});
  });
}
