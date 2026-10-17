// On-device encryption for private sync fields. The data key never leaves the
// phone in readable form: the server only keeps a copy wrapped with a key
// derived from the user's password, so notes and names stay unreadable in
// the database.
//
// AES-GCM and PBKDF2 here are pure Dart. Wrapping and unwrapping run in a
// background isolate (`compute`), and SyncService seals whole requests there
// too, so none of it blocks the UI thread.

import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final AesGcm _aes = AesGcm.with256bits();

/// Encrypts and decrypts single text values with the account's data key.
class DataCipher {
  /// A cipher for the 32-byte [keyBytes].
  DataCipher(List<int> keyBytes)
    : keyBytes = Uint8List.fromList(keyBytes),
      _key = SecretKey(keyBytes);

  /// The raw key, so a background isolate can build its own cipher.
  final Uint8List keyBytes;

  final SecretKey _key;

  /// Marks a sealed value: `enc1:` followed by base64 nonce, text and MAC.
  static const String prefix = 'enc1:';

  /// True when [value] was produced by [seal].
  static bool isSealed(String? value) =>
      value != null && value.startsWith(prefix);

  /// Encrypts [value]. Empty values stay empty so optional fields keep
  /// their meaning, and sealed values are not sealed twice.
  Future<String?> seal(String? value) async {
    if (value == null || value.isEmpty || isSealed(value)) return value;
    final box = await _aes.encrypt(
      utf8.encode(value),
      secretKey: _key,
      nonce: _aes.newNonce(),
    );
    return '$prefix${base64Encode(box.concatenation())}';
  }

  /// Decrypts [value]. Values written before encryption pass through
  /// unchanged; a value that fails to decrypt comes back null rather than
  /// as ciphertext.
  Future<String?> open(String? value) async {
    if (!isSealed(value)) return value;
    try {
      final box = SecretBox.fromConcatenation(
        base64Decode(value!.substring(prefix.length)),
        nonceLength: _aes.nonceLength,
        macLength: _aes.macAlgorithm.macLength,
      );
      return utf8.decode(await _aes.decrypt(box, secretKey: _key));
    } catch (_) {
      return null;
    }
  }
}

/// The data key as the server stores it: encrypted with the password key.
class WrappedDataKey {
  /// A wrapped key with its PBKDF2 [salt] and [iterations].
  const WrappedDataKey({
    required this.salt,
    required this.iterations,
    required this.wrappedKey,
  });

  /// Base64 PBKDF2 salt.
  final String salt;

  /// PBKDF2 iteration count used for this copy.
  final int iterations;

  /// Base64 AES-GCM box (nonce, encrypted key, MAC).
  final String wrappedKey;

  /// Reads the `data_key` object from `/auth/me`; null when incomplete.
  static WrappedDataKey? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final salt = raw['salt']?.toString() ?? '';
    final wrapped = raw['wrapped_key']?.toString() ?? '';
    final iterations = int.tryParse(raw['iterations']?.toString() ?? '');
    if (salt.isEmpty || wrapped.isEmpty || iterations == null) return null;
    return WrappedDataKey(
      salt: salt,
      iterations: iterations,
      wrappedKey: wrapped,
    );
  }

  /// The JSON shape the server stores.
  Map<String, dynamic> toJson() => {
    'salt': salt,
    'iterations': iterations,
    'wrapped_key': wrappedKey,
  };
}

/// A fresh data key and the wrapped copy to upload for it.
class NewDataKey {
  /// Pairs the raw [key] with its [wrapped] upload copy.
  const NewDataKey(this.key, this.wrapped);

  /// The raw 32-byte data key.
  final Uint8List key;

  /// [key] wrapped with the password.
  final WrappedDataKey wrapped;
}

/// Holds the unwrapped key in secure storage for the signed-in account.
class DataKeyStore {
  DataKeyStore._();

  /// The app-wide store.
  static final DataKeyStore instance = DataKeyStore._();

  static const String _storageKey = 'waffer_data_key';

  /// PBKDF2 iterations for new wrapped copies.
  static const int defaultIterations = 210000;

  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  DataCipher? _cached;

  /// The cipher for the stored key, or null when this device has none
  /// (guest, or a session from before encryption).
  Future<DataCipher?> cipher() async {
    final cached = _cached;
    if (cached != null) return cached;
    final stored = (await _secure.read(key: _storageKey))?.trim() ?? '';
    if (stored.isEmpty) return null;
    try {
      return _cached = DataCipher(base64Decode(stored));
    } catch (_) {
      return null;
    }
  }

  /// Stores [key] for this account and caches its cipher.
  Future<void> save(List<int> key) async {
    await _secure.write(key: _storageKey, value: base64Encode(key));
    _cached = DataCipher(key);
  }

  /// Forgets the key (sign-out or account switch).
  Future<void> clear() async {
    _cached = null;
    await _secure.delete(key: _storageKey);
  }

  /// A new random key, wrapped with [password] for upload.
  static Future<NewDataKey> create(
    String password, {
    int iterations = defaultIterations,
  }) async {
    final key = _randomBytes(32);
    return NewDataKey(key, await wrap(key, password, iterations: iterations));
  }

  /// Wraps an existing [key] with [password], e.g. after a password change.
  static Future<WrappedDataKey> wrap(
    List<int> key,
    String password, {
    int iterations = defaultIterations,
  }) async {
    final salt = _randomBytes(16);
    final box = await compute(_wrapKey, (
      key: Uint8List.fromList(key),
      password: password,
      salt: salt,
      iterations: iterations,
    ), debugLabel: 'wrap data key');
    return WrappedDataKey(
      salt: base64Encode(salt),
      iterations: iterations,
      wrappedKey: base64Encode(box),
    );
  }

  /// The raw key inside [wrapped], or null when [password] does not open it.
  static Future<Uint8List?> unwrap(
    String password,
    WrappedDataKey wrapped,
  ) async {
    try {
      return await compute(_unwrapKey, (
        box: base64Decode(wrapped.wrappedKey),
        password: password,
        salt: base64Decode(wrapped.salt),
        iterations: wrapped.iterations,
      ), debugLabel: 'unwrap data key');
    } catch (_) {
      return null;
    }
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}

// Runs in a background isolate: PBKDF2 the password, then seal the key.
Future<Uint8List> _wrapKey(
  ({Uint8List key, String password, Uint8List salt, int iterations}) input,
) async {
  final passwordKey = await _derivePasswordKey(
    input.password,
    input.salt,
    input.iterations,
  );
  final box = await _aes.encrypt(
    input.key,
    secretKey: SecretKey(passwordKey),
    nonce: _aes.newNonce(),
  );
  return Uint8List.fromList(box.concatenation());
}

// Runs in a background isolate. Null when the MAC check fails (wrong
// password); malformed input throws and the caller maps it to null.
Future<Uint8List?> _unwrapKey(
  ({Uint8List box, String password, Uint8List salt, int iterations}) input,
) async {
  final passwordKey = await _derivePasswordKey(
    input.password,
    input.salt,
    input.iterations,
  );
  final box = SecretBox.fromConcatenation(
    input.box,
    nonceLength: _aes.nonceLength,
    macLength: _aes.macAlgorithm.macLength,
  );
  try {
    final key = await _aes.decrypt(box, secretKey: SecretKey(passwordKey));
    return Uint8List.fromList(key);
  } on SecretBoxAuthenticationError {
    return null;
  }
}

// PBKDF2-HMAC-SHA256 is slow on purpose; only ever call it off the UI isolate.
Future<List<int>> _derivePasswordKey(
  String password,
  List<int> salt,
  int iterations,
) async {
  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  );
  final derived = await pbkdf2.deriveKey(
    secretKey: SecretKey(utf8.encode(password)),
    nonce: salt,
  );
  return derived.extractBytes();
}
