# lib/widgets

Controls used by more than one feature. Feature-only widgets stay next to
their screen. Widgets read `core/theme` tokens; only `sheet_amount_field.dart`
and `edit_amount_dialog.dart` read a store (`CurrencyStore`).

| Folder | Use it for |
| --- | --- |
| [`containers/`](containers/README.md) | `GlassContainer` card, `FloatingGlass` chrome, `PinnedPeriodScrollView`, `AppListTile`, `AppEmptyState`, and the sheet toolkit `glass_sheet.dart` (re-exports `sheet_fields`, `sheet_amount_field`, `sheet_transitions`, `sheet_buttons`). |
| [`button/`](button/README.md) | `AppPrimaryButton` (the one primary action, also behind `SheetSaveButton`), `GlassButton` / `GlassIconButton`. |
| [`dialogs/`](dialogs/README.md) | `EditAmountDialog`, `showEditDeleteMenu`, `showWaffrDatePicker` / `showWaffrDateRangePicker`. |
| [`sheets/`](sheets/README.md) | `showMonthlyIncomeRequiredSheet`. |
| [`brand/`](brand/README.md) | `WaffrLogo` / `WaffrSplash`, `WaffrPageHeader` / `WaffrBackHeader`, `ProfileAvatar`, `StreakCelebrationOverlay`. |
| [`motion/`](motion/README.md) | `Reveal`, `staggered()`, `RollingMoney`, `AnimatedRatio`, `RevealClip`, `ActiveListenableBuilder`. Timings come from `AppMotion`. |
| [`smart/`](smart/README.md) | `SmartAnalysisButton` (pill, tile or banner) and the `SmartGlowBackground` / `SmartSpark` effects. |

New sheets should start from `glass_sheet.dart` instead of copying the
padding and the header row. Short explanations open through
`SheetInfoButton` / `showAppInfoDialog`, and confirmations through
`showAppConfirmDialog`, so every (i) and every question looks the same.

Two widgets import from `lib/screens`: `pinned_period_scroll_view.dart`
(shell layout constants) and `smart_analysis_button.dart` (opens
`SmartAnalysisScreen`). Avoid adding more.
