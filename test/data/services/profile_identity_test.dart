// ProfileIdentity: guest vs signed-in display name and email, read from
// prefs and the (mocked) secure-storage token, reload and reset.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/sync/auth_session.dart';
import 'package:waffr/data/services/profile_identity.dart';

import '../../helpers/store_harness.dart';

void main() {
  final identity = ProfileIdentity.instance;

  setUp(() async {
    await setUpStores();
  });

  test('a guest reads «ضيف» even with a saved name', () async {
    final prefs = await setUpStores();
    await prefs.setString('user_name', 'أحمد');
    await prefs.setString(AuthSession.accountEmailKey, 'a@b.co');

    expect(identity.isLoaded, isFalse);
    await identity.ensureLoaded();
    expect(identity.isLoaded, isTrue);
    expect(identity.isLoggedIn, isFalse);
    expect(identity.name, 'أحمد');
    expect(identity.displayName, 'ضيف');
    expect(identity.email, '');
    expect(identity.displayEmail, isNull);
  });

  test('signed in shows the name and the lower-cased email', () async {
    final prefs = await setUpStores();
    await const FlutterSecureStorage().write(
      key: AuthSession.tokenKey,
      value: 'jwt',
    );
    await prefs.setString(AuthSession.accountEmailKey, 'Sara@Mail.COM');
    await prefs.setString('user_name', '  سارة ');

    await identity.reload();
    expect(identity.isLoggedIn, isTrue);
    expect(identity.displayName, 'سارة');
    expect(identity.displayEmail, 'sara@mail.com');
  });

  test('signed in without a name uses the default label', () async {
    await const FlutterSecureStorage().write(
      key: AuthSession.tokenKey,
      value: 'jwt',
    );
    await identity.reload();
    expect(identity.displayName, 'مستخدم وفّر');
    expect(identity.displayEmail, isNull, reason: 'no stored email');
  });

  test('reload notifies only when something changed', () async {
    final prefs = await setUpStores();
    await identity.ensureLoaded();
    var calls = 0;
    void listener() => calls++;
    identity.addListener(listener);
    addTearDown(() => identity.removeListener(listener));

    await identity.reload();
    expect(calls, 0);

    await prefs.setString('user_name', 'جديد');
    await identity.reload();
    expect(calls, 1);
    expect(identity.name, 'جديد');
  });

  test('reset forgets everything', () async {
    final prefs = await setUpStores();
    await prefs.setString('user_name', 'x');
    await identity.ensureLoaded();
    identity.reset();
    expect(identity.isLoaded, isFalse);
    expect(identity.name, '');
    expect(identity.isLoggedIn, isFalse);
  });
}
