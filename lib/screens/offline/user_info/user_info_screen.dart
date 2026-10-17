// Profile form shown as the first signup step, before email and password.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:waffr/widgets/button/app_primary_button.dart';
import 'package:waffr/screens/offline/login/auth_fields.dart';
import 'package:waffr/widgets/brand/waffr_page_header.dart';
import 'package:waffr/data/models/country.dart';
import 'package:waffr/data/models/registration_profile.dart';
import 'package:waffr/core/utils/app_feedback.dart';
import 'package:waffr/core/utils/money.dart';
import 'package:waffr/screens/offline/user_info/country_picker_sheet.dart';
import 'package:waffr/widgets/dialogs/waffr_date_picker.dart';
import 'package:waffr/core/theme/app_motion.dart';
import 'package:waffr/core/theme/app_palette.dart';

/// Gender choice on the profile form. Optional; sent as `male` / `female`.
enum Gender {
  /// Male.
  male,

  /// Female.
  female,
}

/// Collects name, birth date, optional gender, country, an optional phone
/// number (its calling code picked separately), and one address line (city,
/// optional street) for a [RegistrationProfile]. Step 0 of the signup flow.
class UserInfoScreen extends StatefulWidget {
  /// Receives the validated profile when the user taps continue.
  final ValueChanged<RegistrationProfile> onContinue;

  /// Header back action; the back button is hidden when null.
  final VoidCallback? onBack;

  /// Creates a [UserInfoScreen].
  const UserInfoScreen({super.key, required this.onContinue, this.onBack});

  @override
  State<UserInfoScreen> createState() => _UserInfoScreenState();
}

/// State of [UserInfoScreen]. Owns the name, phone and address controllers
/// and the picked date, gender and country.
class _UserInfoScreenState extends State<UserInfoScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  Gender? _selectedGender;
  DateTime? _birthDate;
  CountryInfo? _country;

  /// Calling code for the phone number; picked on its own, independent of
  /// the country of residence.
  CountryInfo? _phoneCountry;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  /// Gender as the string stored on the profile, or null when unset.
  String? get _genderValue {
    if (_selectedGender == Gender.male) return 'male';
    if (_selectedGender == Gender.female) return 'female';
    return null;
  }

  /// Tapping the chosen option again clears it; gender stays optional.
  void _toggleGender(Gender gender) {
    setState(() {
      _selectedGender = _selectedGender == gender ? null : gender;
    });
  }

  /// First validation error for the form, or null when it can be submitted.
  String? get _formError {
    return registrationProfileError(
      name: _nameController.text,
      birthDate: _birthDate,
      gender: _genderValue,
      country: _country?.arabicName ?? '',
      address: _addressController.text,
      phone: _phoneController.text,
    );
  }

  bool get _isFormValid => _formError == null;

  /// Opens the date picker (year view first) for the birth date.
  Future<void> _pickBirthDate() async {
    FocusScope.of(context).unfocus();
    final picked = await showWaffrDatePicker(
      context: context,
      title: 'تاريخ الميلاد',
      initialDate: _birthDate,
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
      startWithYear: true,
    );

    if (picked != null && mounted) {
      setState(() => _birthDate = picked);
    }
  }

  /// Opens the country sheet; also reached from the phone field's code.
  Future<void> _pickCountry() async {
    FocusScope.of(context).unfocus();
    final picked = await showCountryPickerSheet(context, selected: _country);
    if (picked != null && mounted) {
      setState(() => _country = picked);
    }
  }

  /// Opens the picker for the phone calling code, separate from the
  /// country of residence.
  Future<void> _pickPhoneCountry() async {
    FocusScope.of(context).unfocus();
    final picked = await showCountryPickerSheet(
      context,
      selected: _phoneCountry,
    );
    if (picked != null && mounted) {
      setState(() => _phoneCountry = picked);
    }
  }

  /// Shows the first error, or builds the profile (phone prefixed with the
  /// calling code picked for it) and hands it to [UserInfoScreen.onContinue].
  void _continue() {
    final error = _formError;
    if (error != null) {
      showAppSnackBar(context, error);
      return;
    }

    final birthDate = _birthDate;
    final country = _country;
    if (birthDate == null || country == null) return;
    final phoneCountry = _phoneCountry;

    final digits = normalizePhoneNumber(_phoneController.text) ?? '';
    final address = splitAddress(_addressController.text);

    widget.onContinue(
      RegistrationProfile(
        name: _nameController.text.trim(),
        birthDate: birthDate,
        gender: _genderValue,
        country: country.arabicName,
        city: address.city,
        street: address.street,
        phone: digits.isEmpty || phoneCountry == null
            ? ''
            : '${phoneCountry.dialLabel} $digits',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final bg = palette.background;
    final surface = palette.surface;
    final textPrimary = palette.textPrimary;
    final textSecondary = palette.textSecondary;
    final accent = palette.accent;

    return Scaffold(
      backgroundColor: bg,
      appBar: WaffrBackHeader(
        title: 'الملف الشخصي',
        showBack: widget.onBack != null,
        onBack: widget.onBack,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Intro line.
              Text(
                'تساعدنا هذه المعلومات على تقديم تجربة أفضل لك',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: textSecondary),
              ),

              const SizedBox(height: 28),

              // Name.
              AuthFieldLabel(text: 'الاسم', color: textPrimary),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                textAlign: TextAlign.right,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: textPrimary, fontSize: 16),
                decoration: authFieldDecoration(
                  hint: 'الاسم الكامل',
                  fillColor: surface,
                  textSecondary: textSecondary,
                ),
              ),

              const SizedBox(height: 24),

              // Birth date picker row, with the computed age below.
              AuthFieldLabel(text: 'تاريخ الميلاد', color: textPrimary),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickBirthDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _birthDate != null
                            ? formatDate(_birthDate!)
                            : 'DD/MM/YYYY',
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          color: _birthDate != null
                              ? textPrimary
                              : textSecondary.withValues(alpha: 0.6),
                          fontSize: 16,
                        ),
                      ),
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 20,
                        color: accent,
                      ),
                    ],
                  ),
                ),
              ),
              if (_birthDate != null) ...[
                const SizedBox(height: 8),
                Text(
                  'العمر ${ageInYears(_birthDate!)} سنة',
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
              ],

              const SizedBox(height: 24),

              // Optional gender radios.
              AuthFieldLabel(text: 'الجنس (اختياري)', color: textPrimary),
              const SizedBox(height: 4),
              Row(
                children: [
                  _GenderRadio(
                    label: 'ذكر',
                    selected: _selectedGender == Gender.male,
                    accent: accent,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    onTap: () => _toggleGender(Gender.male),
                  ),
                  const SizedBox(width: 28),
                  _GenderRadio(
                    label: 'أنثى',
                    selected: _selectedGender == Gender.female,
                    accent: accent,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    onTap: () => _toggleGender(Gender.female),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Country picker row with its calling code.
              AuthFieldLabel(text: 'الدولة', color: textPrimary),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickCountry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _country?.arabicName ?? 'اختر الدولة',
                          style: TextStyle(
                            color: _country != null
                                ? textPrimary
                                : textSecondary.withValues(alpha: 0.6),
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down_rounded, color: accent),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Single address line, split into city and street on submit.
              AuthFieldLabel(
                text: 'العنوان (الشارع اختياري)',
                color: textPrimary,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _addressController,
                textAlign: TextAlign.right,
                maxLength: maxCityLength + maxStreetLength + 2,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: textPrimary, fontSize: 16),
                decoration: authFieldDecoration(
                  hint: 'مثال: اللاذقية، المشروع الثاني',
                  fillColor: surface,
                  textSecondary: textSecondary,
                ).copyWith(counterText: ''),
              ),

              const SizedBox(height: 24),

              // Optional phone number behind the country's calling code.
              AuthFieldLabel(text: 'رقم الهاتف (اختياري)', color: textPrimary),
              const SizedBox(height: 8),
              _PhoneField(
                controller: _phoneController,
                country: _phoneCountry,
                surface: surface,
                accent: accent,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onPickCountry: _pickPhoneCountry,
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 48),

              // Continue; a disabled tap still explains what is missing.
              AppPrimaryButton(
                label: 'متابعة',
                enabled: _isFormValid,
                onTap: _continue,
                onDisabledTap: _continue,
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round radio mark next to its label. No box around it.
class _GenderRadio extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;

  const _GenderRadio({
    required this.label,
    required this.selected,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: AppMotion.of(context, AppMotion.fast),
                curve: AppMotion.enter,
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? accent
                        : textSecondary.withValues(alpha: 0.6),
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: AppMotion.of(context, AppMotion.fast),
                  curve: AppMotion.overshoot,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Calling code and number in one field. The code sits on the left (numbers
/// read left to right) and opens the country list. The number field stays
/// disabled until a country is picked.
class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final CountryInfo? country;
  final Color surface;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onPickCountry;
  final ValueChanged<String> onChanged;

  const _PhoneField({
    required this.controller,
    required this.country,
    required this.surface,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.onPickCountry,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasCountry = country != null;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // Calling-code button, divider, then the number input.
            InkWell(
              onTap: onPickCountry,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 10, 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hasCountry ? country!.dialLabel : '+',
                      style: TextStyle(
                        color: hasCountry ? accent : textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 20,
                      color: textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: 1,
              height: 26,
              color: textSecondary.withValues(alpha: 0.25),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                enabled: hasCountry,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                  LengthLimitingTextInputFormatter(18),
                ],
                onChanged: onChanged,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  letterSpacing: 0.4,
                ),
                decoration: InputDecoration(
                  hintText: hasCountry
                      ? '9XX XXX XXX'
                      : 'اختر رمز الدولة أولاً',
                  hintTextDirection: hasCountry
                      ? TextDirection.ltr
                      : TextDirection.rtl,
                  hintStyle: TextStyle(
                    color: textSecondary.withValues(alpha: 0.6),
                    fontSize: hasCountry ? 16 : 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
