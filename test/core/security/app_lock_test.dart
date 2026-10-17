// AppLock.setEnabled with a fake LocalAuthentication: turning off needs no
// prompt; turning on needs a supported device and a confirmed prompt.

import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:waffr/core/security/app_lock.dart';

import '../../helpers/store_harness.dart';

class _FakeAuth extends Fake implements LocalAuthentication {
  _FakeAuth({this.supported = true, this.result = true, this.error});

  final bool supported;
  final bool result;
  final Object? error;
  int prompts = 0;

  @override
  Future<bool> isDeviceSupported() async => supported;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<Object> authMessages = const [],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    prompts++;
    if (error != null) throw error!;
    return result;
  }
}

void main() {
  setUp(() async {
    await setUpStores();
  });

  test('off by default; turning off never prompts', () async {
    expect(await AppLock.isEnabled(), isFalse);
    final auth = _FakeAuth();
    var disabled = 0;
    final result = await AppLock.setEnabled(
      enabled: false,
      auth: auth,
      onDisabled: () => disabled++,
    );
    expect(result, AppLockToggleResult.disabled);
    expect(disabled, 1);
    expect(auth.prompts, 0);
  });

  test('a confirmed prompt turns the lock on', () async {
    var enabled = 0;
    final result = await AppLock.setEnabled(
      enabled: true,
      auth: _FakeAuth(),
      onEnabled: () => enabled++,
    );
    expect(result, AppLockToggleResult.enabled);
    expect(enabled, 1);
    expect(await AppLock.isEnabled(), isTrue);
  });

  test('unsupported devices and failed prompts leave it off', () async {
    expect(
      await AppLock.setEnabled(
        enabled: true,
        auth: _FakeAuth(supported: false),
      ),
      AppLockToggleResult.unsupported,
    );
    expect(
      await AppLock.setEnabled(enabled: true, auth: _FakeAuth(result: false)),
      AppLockToggleResult.cancelled,
    );
    expect(
      await AppLock.setEnabled(
        enabled: true,
        auth: _FakeAuth(
          error: const LocalAuthException(
            code: LocalAuthExceptionCode.userCanceled,
          ),
        ),
      ),
      AppLockToggleResult.cancelled,
    );
    expect(
      await AppLock.setEnabled(
        enabled: true,
        auth: _FakeAuth(error: StateError('x')),
      ),
      AppLockToggleResult.cancelled,
    );
    expect(await AppLock.isEnabled(), isFalse);
  });
}
