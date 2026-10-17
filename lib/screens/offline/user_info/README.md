# lib/screens/offline/user_info

The profile form used as the first signup step, before email and password.

| File | Contents |
| --- | --- |
| `user_info_screen.dart` | `UserInfoScreen` and the `Gender` enum. It collects name, birth date, optional gender, country, one address line, and an optional phone number. |
| `country_picker_sheet.dart` | `showCountryPickerSheet(context, selected:)`: a searchable glass sheet of countries with calling codes. It returns the picked `CountryInfo`. |

How it connects:

- `AccountCreationFlow` (in `login/`) hosts `UserInfoScreen` as step 0.
  `onContinue` receives a `RegistrationProfile`, which `RegisterScreen` then
  sends with the new account.
- Validation comes from `registrationProfileError` in
  `data/models/registration_profile.dart`. The continue button stays enabled
  for taps either way and shows the first error as a snack bar.
- The address field is a single line. It is split into city and street with
  `splitAddress`. The phone is stored as `"<dial code> <digits>"`, and the
  number field stays disabled until a country is picked.
- The birth date uses `showWaffrDatePicker` and opens on the year view.
- Countries come from `Countries.search` in `data/models/country.dart`.
- Field chrome (`authFieldDecoration`, `AuthFieldLabel`) is shared with
  `login/auth_fields.dart`.
