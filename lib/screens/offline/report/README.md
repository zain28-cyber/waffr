# Report tab and transaction history

The report tab of the app shell (`ReportScreen`, tab 1) and the transaction
history screen. `reportscreen.dart` is one library split into part files
(`report_*.dart` and `transaction_history_*.dart` start with
`part of 'reportscreen.dart'`). The `expense_history_*.dart` files are
separate libraries for exporting expenses.

| File | What it holds |
| --- | --- |
| `reportscreen.dart` | `ReportScreen`: range chips, period pager (240 pages back), summary cards; per-(range, offset) report cache. |
| `report_data.dart` | Pure period math: `_ReportRange`, `_ReportPeriod`, `_ReportData`, chart bucketing, the comparable previous period, axis label helpers. |
| `report_chart.dart` | `_SpendingChartCard` (one pager page) and `_SpendingLineChart` (fl_chart), `_EmptyState`. |
| `report_summary.dart` | `_SpendingSummary`, `_ExpenseDistribution` (stacked bar + ranked list), `_ImprovementCard` (vs previous period, with the smart analysis button). |
| `transaction_history_screen.dart` | `TransactionHistoryScreen.expenses()` / `.incomes()`: ledger by day, per-row undo, multi-select sharing (expenses only). |
| `transaction_history_rows.dart` | Day groups, history rows, the recurring badge and schedule-text helpers. |
| `transaction_history_dialogs.dart` | Share-format dialog, selection bar, select marks. |
| `expense_history_share.dart` | `shareExpenseHistoryPdf` / `shareExpenseHistoryText`; re-exports the two below. |
| `expense_history_format.dart` | Pure Dart grouping by day, day labels, per-currency totals, plain-text export. |
| `expense_history_pdf.dart` | `buildExpenseHistoryPdfBytes`: reads fonts and logo, then lays out the PDF in a background isolate (`compute`). |

How it connects:

- Data comes from `TransactionStore` (expenses, incomes) and `CategoryStore`;
  the history also reads `RecurringExpenseStore` for schedule text. Undoing
  an expense also reverts a linked shopping-list purchase
  (`ShoppingListStore`).
- `TransactionHistoryScreen` is pushed from the home cards, the report
  summary and smart analysis actions.
- The PDF is shared through the `waffr/share_pdf` method channel on Android
  and `share_plus` elsewhere (or when the channel fails).
- `SpendingImprovement` (core/insights) computes the comparison; the
  previous period is cut to the same elapsed span while the current one is
  still running.

Tests: `test/screens/offline/report/reportscreen_test.dart`,
`test/screens/offline/report/expense_history_pdf_test.dart`.
