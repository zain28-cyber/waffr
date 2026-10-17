# test/data

Unit tests for `lib/data`.

- [models/](models/README.md): JSON, sync rows and value logic of every
  model.
- [stores/](stores/README.md): the prefs-backed stores.
- [services/](services/README.md): notifications, streak, settings,
  account data and home widget data.

Store and service tests start from an empty device with `setUpStores()`
(see `test/README.md`).

```
flutter test --no-pub test/data
```
