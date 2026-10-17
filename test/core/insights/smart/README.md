# test/core/insights/smart

The on-device smart analysis. Most tests build `SmartFacts` directly with
`buildFacts` from `test/helpers/ledger_builders.dart` and a fixed "now",
so they need no stores; `smart_facts_loader_test.dart` reads the real
stores through `setUpStores()`.

- `smart_facts_test.dart`: every derived figure.
- `report_insights_test.dart`, `savings_insights_test.dart`,
  `profile_insights_test.dart`: which cards each rule writes.
- `insight_engine_test.dart`: whole reports, ranking and seeds.
- `insight_summary_test.dart`, `insight_phrasing_test.dart`: headline,
  summary, tip and wording helpers.
- `reminder_digest_test.dart`, `notification_texts_test.dart`: reminder
  texts and a grammar/cleanliness check over many random ledgers.
- `arabic_text_test.dart`, `category_suggester_test.dart`,
  `smart_insight_test.dart`.

Generated text is random per seed, so tests pin a seed or check every
phrasing (`anyOf`, loops over seeds).

```
flutter test --no-pub test/core/insights/smart
```
