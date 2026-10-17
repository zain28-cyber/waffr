# test/data/models

One file per model in `lib/data/models`: prefs encode/decode round trips,
`fromSync`/`toSync` rows, rejection of missing or invalid fields and their
defaults, `copyWith` (including the `touch` and clear flags), equality-like
helpers (`sameDetailsAs`), calendar period math, the currency catalog and
the country search.

```
flutter test --no-pub test/data/models
```
