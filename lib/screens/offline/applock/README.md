# lib/screens/offline/applock

The biometric/PIN app lock.

| File | Contents |
| --- | --- |
| `applockscreen.dart` | `LockScreen`: asks for device authentication (`local_auth`, biometrics or device PIN) and calls `onAuthenticated` on success. |

How it connects:

- `main.dart` shows `LockScreen` while the `app_lock` pref is on and the
  current foreground session is not yet unlocked. Once the shell has been
  built, it stays mounted underneath, offstage and with its tickers paused,
  so a lock never throws away tab state.
- `main.dart` locks again when the app is paused. Settings turns the lock
  on or off and calls `refreshAppLockState` on the flow controller.
- The prompt opens automatically after the first frame. The unlock button
  retries it. A cancelled or failed attempt leaves the screen locked.
- A device without auth support is let through immediately.
