# test

Flutter tests for the app. The tree mirrors `lib/`: the tests for
`lib/<path>/<file>.dart` live in `test/<path>/<file>_test.dart` (a few
files group related libraries, for example `transaction_store_*_test.dart`
follows the part files of `TransactionStore`).

| Folder | What it covers |
| --- | --- |
| [core/](core/README.md) | Pure logic: insights, sync, usage, utils, prefs, security |
| [data/](data/README.md) | Models, prefs-backed stores and services |
| [helpers/](helpers/README.md) | Shared setup and builders, not tests themselves |
| [screens/](screens/README.md) | Widget smoke tests for `lib/screens` |
| [widgets/](widgets/README.md) | Widget tests for `lib/widgets` |

`core/` and `data/` hold unit tests (another engineer owns the widget
tests under `screens/` and `widgets/`). A few older UI tests still sit at
the root of `test/` until they are moved next to their screens.

## Store state between tests

Every store and service is an app-wide singleton backed by
SharedPreferences. Tests that touch them call `setUpStores()` from
`helpers/store_harness.dart` in `setUp`. It installs an empty in-memory
SharedPreferences, clears the instance `AppPrefs` caches, mocks secure
storage with `FlutterSecureStorage.setMockInitialValues`, and calls every
store's `resetCache()` (plus `ProfileIdentity.reset()`, the streak clock
and `SyncDirty.suppressed`). To start from saved data, write it with the
returned prefs and call `resetStoreCaches()` so the stores read it again;
that is also how persistence round trips are tested.

No test touches the network or a real platform channel. Plugins without a
test implementation (notifications, home widgets, path provider) fail
quietly inside the app code; where a test needs to see the calls, it
mocks the method channel with `TestDefaultBinaryMessengerBinding`.

## Running

```
flutter test --no-pub                      # everything
flutter test --no-pub test/core test/data  # unit tests only
flutter analyze --no-pub test
```
