# lib/widgets/button

The two shared button families. Both are drawn without `BackdropFilter`
so they stay cheap to paint.

| File | Contents |
| --- | --- |
| `app_primary_button.dart` | `AppPrimaryButton(label:, onTap:)`: the app's one primary action. Full width, accent fill, bold label, optional `icon`; `busy` shows a spinner and ignores taps; `enabled: false` greys it out and routes taps to `onDisabledTap` so a form can explain what is missing. |
| `glass_button.dart` | `GlassButton`: a pressable `GlassContainer` that sinks on touch and springs back (`onTap`, `onLongPress`, `colorType`, sizing). `GlassIconButton`: the square glass icon button with label, `dimmed` and an optional `showDot` badge. |

Who uses them:

- `AppPrimaryButton`: login/register/forgot-password, app lock, theme
  select, user info, change password, currencies sheet, manage goals, and
  every sheet through `SheetSaveButton` (`widgets/containers/sheet_buttons.dart`).
- `GlassButton` / `GlassIconButton`: `AppShell` header actions (settings,
  bell with dot), balance card shortcuts, dashboard, reports, savings,
  online tab and the shopping list.

Conventions:

- A screen or sheet has at most one `AppPrimaryButton`; do not style a
  custom `ElevatedButton` for the main action. Destructive actions under
  it use `SheetDestructiveButton`.
- Press animations use `AppMotion` timings and colors come from
  `AppPalette`, so both honor reduced motion and dark mode.
