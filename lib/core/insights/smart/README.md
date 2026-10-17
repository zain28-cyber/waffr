# lib/core/insights/smart

The "smart analysis": rule-based insights written in Arabic, entirely on the
device (no network, no model). Data flows one way:
stores -> `SmartFactsLoader` -> `SmartFacts` -> `InsightEngine` -> `SmartReport`.

| File | Contents |
| --- | --- |
| `smart_facts.dart` | `SmartFacts` (plus `GoalFact`, `ObligationFact`): the numbers for one run, with lazily cached derived figures. Pure data, so rules are testable without stores. |
| `smart_facts_loader.dart` | `SmartFactsLoader.load()`: awaits the stores and snapshots the active currency into `SmartFacts`. |
| `smart_insight.dart` | Output types: `InsightScope` (reports / savings / profile), `InsightTone`, `HealthBand`, `InsightAction`, `SmartInsight`, `SmartReport`. |
| `insight_engine.dart` | `InsightEngine(facts, seed:).analyze(scope)`: runs one rule group, ranks and caps the cards, adds the closing tip. Also `healthScore()` and `suggestedMonthlySaving()`. |
| `report_insights.dart` | `ReportInsights.all()`: spending rules (trends, top category, spikes, projection, runway, weekday, small/large/night spending). Also `largestCategory()`. |
| `savings_insights.dart` | `SavingsInsights.all()`: goals, saving rate, withdrawals, emergency fund; `suggestedMonthlySaving()`. |
| `profile_insights.dart` | `ProfileInsights.all()` and the weighted 0-100 `healthScore()`; `healthLabel(score)`. |
| `insight_summary.dart` | `InsightSummary`: headline, summary line and closing tip of a report. |
| `insight_phrasing.dart` | `InsightPhrasing`: shared random wording, money/percent formatting, openers and closers (each used once per report). |
| `arabic_text.dart` | Arabic grammar helpers: `ArabicCount` / `Ar` (number-noun agreement), `Ar.category`, `Ar.li`, `Ar.quote`. |
| `reminder_digest.dart` | `ReminderDigest(facts).candidates(fireAt)` / `weekly()` / `streakText()`: short factual texts for device notifications. |
| `category_suggester.dart` | `CategorySuggester(history).suggest(note, allowed)`: picks a category from the expense note, learning from the user's history first, then a dictionary. |

Conventions:

- `insight_engine.dart` was split: rules live in the `*_insights.dart` files,
  wording in `insight_phrasing.dart`, framing text in `insight_summary.dart`.
- One `InsightPhrasing` and one `Random` are shared by all rule groups in a
  fixed call order, so a fixed `seed` gives the exact same report (tests).
- Cards are cut by priority alone; only ordering inside the cut is jittered.
- Money is formatted through `core/utils/money.dart`; percents are wrapped
  in LTR isolates so "20%" does not flip inside Arabic text.

Users: `SmartAnalysisScreen` and `ProfileScreen` (engine + loader),
`AppShell` and `SystemNotifications` (reminder digest), the add-expense sheet
(category suggester), `NotificationService`, `RecurringExpenseStore` and
`HomeWidgetSync` (`arabic_text.dart`).
