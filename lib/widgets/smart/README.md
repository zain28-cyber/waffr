# Smart effects

| File | Contents |
| --- | --- |
| `smart_analysis_button.dart` | `SmartAnalysisButton(scope:, style:)`: opens `SmartAnalysisScreen` for an `InsightScope`, drawn as a header pill, an in-card tile or a full-width banner (`SmartButtonStyle`). |
| `smart_glow.dart` | `SmartGlowBackground` (drifting color glow), `SmartSpark` (spinning spark while the analysis writes), `SmartGradientIcon`, `smartGlowColors()`. |

`SmartAnalysisButton` opens the local insight screen (`core/insights/smart`). Its introductory border
turns until the user opens an analysis, but only while its tab is visible and
the device allows motion. The shared seen flag (`smart_analysis_seen`) is
stored in preferences and read from `AppPrefs.cached` during build.

`SmartGlowBackground` paints its drift through a `CustomPainter` repaint
listener rather than rebuilding the screen each frame. Hidden, transparent,
and reduced-motion backgrounds stop their drift controller.

`SmartSpark` owns its rotation and its settling state. Rebuilding an already
settling spark must not restart its animation. Resuming generation cancels
that settling state directly; no delayed callback can reset a new spin or
write to a disposed controller. Painter comparisons include gradient colors.

Generation cancellation belongs to `SmartAnalysisScreen`, not these effects.
That screen cancels its thinking timer and artificial pause on scope changes
or disposal, discards superseded fact loads, and caps typing-related text
layout updates at roughly 30 Hz. Glow/rotation can still animate independently.

Tests cover rapid spinner toggles, reduced-motion changes, hidden effects,
navigation during generation, and rapidly changing the insight scope.
