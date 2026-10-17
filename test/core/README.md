# test/core

Unit tests for `lib/core`: plain Dart logic with no UI.

- [insights/](insights/README.md): the smart analysis, reminder texts and
  spending comparisons.
- [sync/](sync/README.md): the /sync request and reply, merging, delete
  logs, dirty flags, encryption of private fields, auth error copy.
- [usage/](usage/README.md): streak rules and usage duration text.
- [utils/](utils/README.md): money and date formatting, typed dates.
- [prefs/](prefs/README.md): the cached SharedPreferences handle.
- [security/](security/README.md): the data key and the app lock.

```
flutter test --no-pub test/core
```
