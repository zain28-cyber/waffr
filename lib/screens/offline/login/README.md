# lib/screens/offline/login

Account screens: sign in, create an account, reset a password, or continue
as a guest.

| File | Contents |
| --- | --- |
| `login_screen.dart` | `LoginScreen`: email/password sign-in, plus links to register, forgot password, and (optionally) guest mode. |
| `account_creation_flow.dart` | `AccountCreationFlow`: the two signup steps on one route. Step 0 is `UserInfoScreen`, step 1 is `RegisterScreen`. |
| `register_screen.dart` | `RegisterScreen`: email, password and confirmation, sent with the `RegistrationProfile` from step 0. |
| `forgot_password_screen.dart` | `ForgotPasswordScreen`: request an emailed 6-digit code, then set a new password. Pops with `(email, password)`. |
| `auth_fields.dart` | `authFieldDecoration` and `AuthFieldLabel`, the shared field chrome. Also used by `user_info/`. |

How it connects:

- `main.dart` shows `LoginScreen` as the first gate. Settings and the online
  tab push it again with `allowGuest: false` and `popOnSuccess: true`.
- All requests go through `AuthSession` (`login`, `register`,
  `requestPasswordReset`, `resetPassword`). A successful login or
  registration is followed by `SyncService.syncNow()`. Guest mode goes through
  `BackupService.continueAsGuest()`.
- A login also clears the `first_launch` pref, so a returning user skips
  the theme picker.
- After a password reset, `LoginScreen` fills in the returned credentials
  and signs in right away.
- Each screen shows errors inline with `AppInlineMessage`. Tapping a disabled
  main button explains what is missing.
- In `AccountCreationFlow`, system back on step 1 returns to step 0. Step 0
  stays mounted offstage, so its fields survive the trip back.
