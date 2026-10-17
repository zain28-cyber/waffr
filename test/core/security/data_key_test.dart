// DataCipher sealing, WrappedDataKey JSON, and DataKeyStore: create / wrap /
// unwrap round trips (through compute) and the cached key in mocked secure
// storage.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/security/data_key.dart';

import '../../helpers/store_harness.dart';

void main() {
  group('DataCipher', () {
    final cipher = DataCipher(List<int>.generate(32, (i) => 255 - i));

    test(
      'seal then open gives the text back, with a fresh nonce each time',
      () async {
        final a = await cipher.seal('مرحبا 123');
        final b = await cipher.seal('مرحبا 123');
        expect(DataCipher.isSealed(a), isTrue);
        expect(a, isNot(b));
        expect(await cipher.open(a), 'مرحبا 123');
        expect(await cipher.open(b), 'مرحبا 123');
      },
    );

    test('isSealed checks the prefix', () {
      expect(DataCipher.isSealed(null), isFalse);
      expect(DataCipher.isSealed('enc1:'), isTrue);
      expect(DataCipher.isSealed('ENC1:x'), isFalse);
    });

    test('tampered ciphertext opens as null', () async {
      final sealed = (await cipher.seal('سر'))!;
      final flipped =
          '${sealed.substring(0, sealed.length - 2)}'
          '${sealed.endsWith('A=') ? 'B=' : 'A='}';
      expect(await cipher.open(flipped), isNull);
    });

    test('keeps a copy of the key bytes', () {
      final key = List<int>.filled(32, 1);
      final c = DataCipher(key);
      key[0] = 9;
      expect(c.keyBytes[0], 1);
    });
  });

  group('WrappedDataKey', () {
    test('JSON round trip and incomplete input', () {
      const wrapped = WrappedDataKey(salt: 's', iterations: 5, wrappedKey: 'w');
      expect(wrapped.toJson(), {
        'salt': 's',
        'iterations': 5,
        'wrapped_key': 'w',
      });
      final back = WrappedDataKey.fromJson({
        'salt': 's',
        'iterations': '5',
        'wrapped_key': 'w',
      })!;
      expect(back.iterations, 5);

      expect(WrappedDataKey.fromJson(null), isNull);
      expect(
        WrappedDataKey.fromJson({
          'salt': '',
          'iterations': 1,
          'wrapped_key': 'w',
        }),
        isNull,
      );
      expect(
        WrappedDataKey.fromJson({
          'salt': 's',
          'iterations': 'x',
          'wrapped_key': 'w',
        }),
        isNull,
      );
      expect(WrappedDataKey.fromJson({'salt': 's', 'iterations': 1}), isNull);
    });
  });

  group('DataKeyStore', () {
    setUp(() async {
      await setUpStores();
    });

    test('create gives a 32-byte key that only the password unwraps', () async {
      final created = await DataKeyStore.create('secret', iterations: 500);
      expect(created.key, hasLength(32));
      expect(created.wrapped.iterations, 500);
      expect(await DataKeyStore.unwrap('secret', created.wrapped), created.key);
      expect(await DataKeyStore.unwrap('Secret', created.wrapped), isNull);
    });

    test('two keys are different', () async {
      final a = await DataKeyStore.create('p', iterations: 10);
      final b = await DataKeyStore.create('p', iterations: 10);
      expect(a.key, isNot(b.key));
      expect(a.wrapped.salt, isNot(b.wrapped.salt));
    });

    test(
      'malformed wrapped data unwraps to null instead of throwing',
      () async {
        const bad = WrappedDataKey(
          salt: '!!',
          iterations: 10,
          wrappedKey: '??',
        );
        expect(await DataKeyStore.unwrap('p', bad), isNull);
      },
    );

    test('save, read back from storage and clear', () async {
      final store = DataKeyStore.instance;
      expect(await store.cipher(), isNull);

      final key = List<int>.generate(32, (i) => i);
      await store.save(key);
      final cipher = (await store.cipher())!;
      expect(cipher.keyBytes, key);
      expect(identical(await store.cipher(), cipher), isTrue, reason: 'cached');

      await store.clear();
      expect(await store.cipher(), isNull);
    });

    test('a corrupt stored key reads as no key', () async {
      await DataKeyStore.instance.clear();
      FlutterSecureStorage.setMockInitialValues({
        'waffer_data_key': 'not base64!',
      });
      expect(await DataKeyStore.instance.cipher(), isNull);
    });
  });
}
