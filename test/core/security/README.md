# test/core/security

`data_key_test.dart`: sealing and opening text with `DataCipher`, the
wrapped key JSON, and creating, wrapping and unwrapping the data key with
a password (PBKDF2 runs through `compute`, with low iteration counts to
stay fast). Secure storage is mocked.

`app_lock_test.dart`: `AppLock.setEnabled` with a fake
`LocalAuthentication`.

```
flutter test --no-pub test/core/security
```
