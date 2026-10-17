# Profile and wallet expression

| File | Main entry point | What it is |
| --- | --- | --- |
| `profile_screen.dart` | `ProfileScreen` | Profile tab (shell tab 4): identity header, streak, usage duration, smart analysis button, usage counts, over the wallet backdrop. |
| `streak_card.dart` | `StreakCard` | Day count, milestone ring with the Waffr mark, and this week's days (Saturday to Friday; days still ahead stay faded). |
| `wallet_backdrop.dart` | `WalletBackdrop` | The large faint wallet behind the cards, with a vector mouth driven by `HealthBand`. |

`ProfileScreen` displays the identity (`ProfileIdentity`), usage streak
(`UsageStreakService`), usage statistics (`ProfileSnapshot.fromStore`) and the
wallet backdrop. Identity editing remains in Settings. The balance scale was
removed; it must not be restored as part of motion/performance fixes.

The wallet's mouth follows the same `HealthBand` as the profile insight report
(`InsightEngine(facts).healthScore()` on `SmartFactsLoader.load()`):
excellent and good smile, fair is nearly neutral, and low frowns. The score's
savings component compares net average monthly saving to income; a 20% rate
gets full credit, withdrawals reduce net saving, and the average uses up to
three months of available history. Other factors are obligations, balance
coverage, spending trend and logging consistency. Missing income omits
income-dependent factors. With no financial movements the backdrop keeps the
brand's default smile.

`WalletBackdrop` precaches the mouthless logo, draws a vector mouth and morphs
between bands. Its breath is isolated from static artwork by a repaint
boundary. Hidden/reduced-motion pages stop breathing. Reduced motion settles
appearance and mouth changes immediately.

Health refreshes are coalesced (zero-delay timer) and serialized. Changes on a
hidden tab only mark the score dirty; returning computes the latest result. An
older load is discarded if data changed while it was waiting. `StreakCard`
only replays for a replay-token change (bumped when the tab is revisited) and
shows final values directly with reduced motion.

Tests: `test/profile_wallet_health_test.dart`,
`test/wallet_backdrop_motion_test.dart`,
`test/screens/offline/profile/profile_screen_test.dart`.
