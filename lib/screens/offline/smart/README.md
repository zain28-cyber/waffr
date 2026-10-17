# Smart analysis

The full-screen local analysis of the user's finances. One library:
`smart_analysis_screen.dart` holds the imports and `part` directives; the
other two files start with `part of 'smart_analysis_screen.dart'`.

| File | What it holds |
| --- | --- |
| `smart_analysis_screen.dart` | `openSmartAnalysis(context, scope)` (fade + zoom route), `SmartAnalysisScreen`, `smartSparkHeroTag`. Phases: thinking, writing (typed out), done. |
| `smart_analysis_cards.dart` | `_InsightCard` (expandable detail and action button), `_HealthGauge` and its painter. |
| `smart_analysis_thinking.dart` | `_ThinkingView` shimmer placeholders, `_TypedText` and its caret. |

How it connects:

- Opened from `SmartAnalysisButton` (widgets/smart), the AI permissions
  screen, and the shell when a smart reminder notification is tapped.
- Each run loads `SmartFactsLoader.load()` and builds a `SmartReport` with
  `InsightEngine(facts, seed: ...).analyze(scope)`. Everything is local; no
  network call is made. Scope chips rerun it for another `InsightScope`.
- Insight actions open the matching sheet or screen: add expense / income,
  create goal, manual save, obligations, shopping list, expense history.
  If `TransactionStore`, `RecurringExpenseStore` or `ShoppingListStore`
  changed meanwhile, the analysis reruns quickly.

Conventions: the headline, summary and card bodies are typed as one
character stream (about three seconds, driven by elapsed ticker time and
throttled to ~30 Hz); a tap shows everything at once. Reduced motion skips
the thinking pause and the typing. A run counter (`_run`) discards results of
a superseded run. The `health-score` insight is shown only as the gauge.

Tests: `test/screens/offline/smart/smart_analysis_screen_test.dart`,
`test/screens/offline/smart/smart_generation_lifecycle_test.dart`.
