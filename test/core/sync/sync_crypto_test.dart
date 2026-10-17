// Field sealing for /sync (sealSyncRequest / openSyncResponse) and the
// password-wrapped data key that the cipher uses.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/security/data_key.dart';
import 'package:waffr/core/sync/sync_crypto.dart';

void main() {
  final cipher = DataCipher(List<int>.generate(32, (i) => i));

  test('seals private text and leaves amounts readable', () async {
    final request = <String, dynamic>{
      'transactions': {
        'upserts': [
          {
            'client_id': 'tx1',
            'amount': '250.5',
            'category': 'طعام',
            'payment_method': null,
            'note': 'عشاء',
          },
        ],
        'deletes': [],
      },
      'notifications': {
        'upserts': [
          {
            'client_id': 'n1',
            'title': 'هدف',
            'message': 'وصلت',
            'event_key': 'goalReached:g1',
            'metadata': const {'goalName': 'سيارة', 'percent': '100'},
          },
        ],
        'deletes': [],
      },
    };

    await sealSyncRequest(request, cipher);

    final tx = request['transactions']['upserts'][0] as Map;
    expect(tx['amount'], '250.5');
    expect(tx['payment_method'], isNull);
    expect(DataCipher.isSealed(tx['category'] as String), isTrue);
    expect(DataCipher.isSealed(tx['note'] as String), isTrue);

    final note = request['notifications']['upserts'][0] as Map;
    expect(note['event_key'], 'goalReached:g1');
    expect(DataCipher.isSealed(note['metadata']['goalName'] as String), isTrue);

    final sawPlaintext = await openSyncResponse(request, cipher);
    expect(sawPlaintext, isFalse);
    expect(tx['category'], 'طعام');
    expect(tx['note'], 'عشاء');
    expect(note['metadata'], {'goalName': 'سيارة', 'percent': '100'});
  });

  test('reports text the server still holds unencrypted', () async {
    final body = <String, dynamic>{
      'savings_goals': {
        'upserts': [
          {'client_id': 'g1', 'name': 'سفر', 'target_amount': '100'},
        ],
      },
    };
    expect(await openSyncResponse(body, cipher), isTrue);
    expect(body['savings_goals']['upserts'][0]['name'], 'سفر');
  });

  test('a different key cannot read sealed text', () async {
    final sealed = await cipher.seal('سري');
    final other = DataCipher(List<int>.filled(32, 7));
    expect(await other.open(sealed), isNull);
  });

  test('the password unwraps the data key and a wrong one does not', () async {
    final created = await DataKeyStore.create('pass-1234', iterations: 1000);
    expect(
      await DataKeyStore.unwrap('pass-1234', created.wrapped),
      created.key,
    );
    expect(await DataKeyStore.unwrap('wrong', created.wrapped), isNull);

    final restored = WrappedDataKey.fromJson(created.wrapped.toJson());
    expect(restored, isNotNull);
    expect(await DataKeyStore.unwrap('pass-1234', restored!), created.key);
  });

  test('a password change re-wraps the same key', () async {
    final created = await DataKeyStore.create('old-pass-1', iterations: 1000);
    final rewrapped = await DataKeyStore.wrap(
      created.key,
      'new-pass-2',
      iterations: 1000,
    );
    expect(await DataKeyStore.unwrap('new-pass-2', rewrapped), created.key);
    expect(await DataKeyStore.unwrap('old-pass-1', rewrapped), isNull);
  });

  test('only listed collections and fields are touched', () async {
    final request = <String, dynamic>{
      'transactions': {
        'upserts': [
          {'client_id': 't', 'amount': '1', 'note': '', 'category': 5},
          'junk',
        ],
      },
      'settings': {'display_name': 'سارة'},
      'shopping_lists': {
        'upserts': [
          {'client_id': 'l', 'name': 'المشتريات'},
        ],
      },
      'savings_goals': 'not a section',
    };
    await sealSyncRequest(request, cipher);
    final row = request['transactions']['upserts'][0] as Map;
    expect(row['note'], '', reason: 'empty text stays empty');
    expect(row['category'], 5, reason: 'non-strings are left alone');
    expect(request['settings']['display_name'], 'سارة');
    expect(request['shopping_lists']['upserts'][0]['name'], 'المشتريات');
  });

  test('sealing twice does not double-seal', () async {
    final once = await cipher.seal('نص');
    expect(await cipher.seal(once), once);
    expect(await cipher.seal(null), isNull);
    expect(await cipher.seal(''), '');
  });

  test('opening garbage gives null, plain text passes through', () async {
    expect(await cipher.open('enc1:not-base64!'), isNull);
    expect(await cipher.open('plain'), 'plain');
    expect(await cipher.open(null), isNull);
  });

  test('every private collection is listed with its fields', () {
    expect(
      privateSyncFields.keys,
      containsAll([
        'transactions',
        'savings_transfers',
        'savings_goals',
        'shopping_items',
        'recurring_expenses',
        'notifications',
        'expense_categories',
        'expense_presets',
      ]),
    );
    expect(privateSyncFields['transactions'], isNot(contains('amount')));
  });
}
