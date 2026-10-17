// Tests for the /sync request and reply codec: fingerprint filtering,
// sealing, and opening the reply.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/security/data_key.dart';
import 'package:waffr/core/sync/sync_codec.dart';
import 'package:waffr/core/sync/sync_sent_rows.dart';

final Uint8List _key = Uint8List.fromList(List<int>.generate(32, (i) => i));

Map<String, dynamic> _request({String note = 'غداء', List deletes = const []}) {
  return {
    'last_sync_at': null,
    'transactions': {
      'upserts': [
        {'client_id': 't1', 'amount': '10.0', 'note': note, 'category': 'طعام'},
        {'client_id': 't2', 'amount': '20.0', 'note': null, 'category': 'صحة'},
      ],
      'deletes': deletes,
    },
    'shopping_lists': {
      'upserts': [
        {'client_id': 'shopping_default', 'name': 'المشتريات'},
      ],
      'deletes': [],
    },
    'settings': null,
  };
}

void main() {
  group('syncRowFingerprint', () {
    test('is stable for equal rows and changes with any field', () {
      final a = {'client_id': 'x', 'amount': '1.0', 'note': 'a'};
      final b = {'client_id': 'x', 'amount': '1.0', 'note': 'a'};
      final c = {'client_id': 'x', 'amount': '1.0', 'note': 'b'};
      expect(syncRowFingerprint(a), syncRowFingerprint(b));
      expect(syncRowFingerprint(a), isNot(syncRowFingerprint(c)));
    });
  });

  group('encodeSyncRequest', () {
    test(
      'without known prints sends every row and seals private text',
      () async {
        final encoded = await encodeSyncRequest(
          SyncRequestJob(payload: _request(), keyBytes: _key),
        );
        final body = jsonDecode(encoded.body) as Map;
        final rows = body['transactions']['upserts'] as List;
        expect(rows, hasLength(2));
        expect(DataCipher.isSealed(rows[0]['note'] as String), isTrue);
        expect(rows[0]['amount'], '10.0');
        expect(encoded.sent['transactions']!.keys, containsAll(['t1', 't2']));
      },
    );

    test('skips rows the server already has and keeps changed ones', () async {
      final first = await encodeSyncRequest(
        SyncRequestJob(payload: _request(), keyBytes: _key),
      );
      final memory = SyncSentRows()..remember(first.sent, replace: true);

      final second = await encodeSyncRequest(
        SyncRequestJob(
          payload: _request(note: 'عشاء'),
          keyBytes: _key,
          known: memory.known,
        ),
      );
      final rows = (jsonDecode(second.body) as Map)['transactions']['upserts'];
      expect([for (final row in rows) row['client_id']], ['t1']);
      // The shopping list row is never filtered.
      final lists = (jsonDecode(second.body) as Map)['shopping_lists'];
      expect(lists['upserts'], hasLength(1));
    });

    test('a row with a pending tombstone is always sent', () async {
      final first = await encodeSyncRequest(
        SyncRequestJob(payload: _request(), keyBytes: _key),
      );
      final memory = SyncSentRows()..remember(first.sent, replace: true);
      final second = await encodeSyncRequest(
        SyncRequestJob(
          payload: _request(
            deletes: [
              {'client_id': 't2', 'deleted_at': '2026-01-01T00:00:00Z'},
            ],
          ),
          keyBytes: _key,
          known: memory.known,
        ),
      );
      final rows = (jsonDecode(second.body) as Map)['transactions']['upserts'];
      expect([for (final row in rows) row['client_id']], ['t2']);
    });
  });

  group('SyncSentRows', () {
    test('forgets ids whose tombstones reached the server', () {
      final memory = SyncSentRows()
        ..remember({
          'transactions': {'t1': 'a', 't2': 'b'},
        }, replace: true);
      memory.remember(
        const {},
        replace: false,
        deleted: {
          'transactions': ['t1'],
        },
      );
      expect(memory.known['transactions'], {'t2': 'b'});
    });

    test('a full push replaces the memory', () {
      final memory = SyncSentRows()
        ..remember({
          'transactions': {'t1': 'a'},
        }, replace: true)
        ..remember({
          'savings_goals': {'g1': 'c'},
        }, replace: true);
      expect(memory.known.containsKey('transactions'), isFalse);
      expect(memory.known['savings_goals'], {'g1': 'c'});
      memory.clear();
      expect(memory.isEmpty, isTrue);
    });
  });

  group('decodeSyncResponse', () {
    test('opens sealed text and reports plaintext from the server', () async {
      final sealed = await DataCipher(_key).seal('سري');
      final reply = jsonEncode({
        'savings_goals': {
          'upserts': [
            {'client_id': 'g1', 'name': sealed},
            {'client_id': 'g2', 'name': 'قديم'},
          ],
        },
      });
      final decoded = await decodeSyncResponse((body: reply, keyBytes: _key));
      final rows = decoded.body!['savings_goals']['upserts'] as List;
      expect(rows[0]['name'], 'سري');
      expect(rows[1]['name'], 'قديم');
      expect(decoded.sawPlaintext, isTrue);
    });

    test('a reply that is not an object has no body', () async {
      final decoded = await decodeSyncResponse((body: '[]', keyBytes: _key));
      expect(decoded.body, isNull);
    });

    test('the background variant gives the same result', () async {
      final decoded = await decodeSyncResponseInBackground('{"a": 1}', _key);
      expect(decoded.body, {'a': 1});
      expect(decoded.sawPlaintext, isFalse);
    });
  });
}
