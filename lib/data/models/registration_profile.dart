// Signup profile fields and validation before the account credentials step.

/// Demographics collected during registration, sent with the auth request.
/// Gender, phone and address are optional.
class RegistrationProfile {
  /// Display name.
  final String name;

  /// Date of birth.
  final DateTime birthDate;

  /// "male", "female" or null when not given.
  final String? gender;

  /// Country name.
  final String country;

  /// City (required by the form).
  final String city;

  /// Street (optional).
  final String street;

  /// Full international number ("+963 912345678"), or empty.
  final String phone;

  /// A sign-up profile.
  const RegistrationProfile({
    required this.name,
    required this.birthDate,
    required this.country,
    this.gender,
    this.city = '',
    this.street = '',
    this.phone = '',
  });

  /// Flattened map for the signup API; omits empty optional fields.
  Map<String, String> toAuthBody() {
    final cityText = city.trim();
    final address = street.trim();
    final phoneText = phone.trim();
    return {
      'name': name.trim(),
      'gender': ?gender,
      'birthdate': birthDate.toIso8601String(),
      'country': country.trim(),
      if (cityText.isNotEmpty) 'city': cityText,
      if (address.isNotEmpty) 'street': address,
      if (phoneText.isNotEmpty) 'phone': phoneText,
    };
  }
}

/// Longest accepted city name.
const int maxCityLength = 80;

/// Longest accepted street text.
const int maxStreetLength = 160;

/// One "city, street" field split for the account: the city comes before
/// the first comma and is required; the street after it is optional.
/// Without a comma the whole text is the city.
({String city, String street}) splitAddress(String raw) {
  final text = raw.trim();
  final comma = text.indexOf(RegExp('[,،]'));
  if (comma < 0) return (city: text, street: '');
  return (
    city: text.substring(0, comma).trim(),
    street: text.substring(comma + 1).trim(),
  );
}

/// Digits of a local phone number without a leading trunk zero, or null
/// when it is not a plausible number. Empty input is allowed (optional).
String? normalizePhoneNumber(String raw) {
  var digits = raw.replaceAll(RegExp(r'[\s\-()]'), '');
  if (digits.isEmpty) return '';
  if (!RegExp(r'^[0-9]+$').hasMatch(digits)) return null;
  if (digits.startsWith('0')) digits = digits.substring(1);
  if (digits.length < 6 || digits.length > 14) return null;
  return digits;
}

/// Full years between birth and today (or [today] when testing).
int ageInYears(DateTime birth, [DateTime? today]) {
  final now = today ?? DateTime.now();
  var age = now.year - birth.year;
  final birthdayPassed =
      now.month > birth.month ||
      (now.month == birth.month && now.day >= birth.day);
  if (!birthdayPassed) age -= 1;
  if (age < 0) return 0;
  return age;
}

/// True when the chosen birth date is not in the future.
bool isValidBirthDate(DateTime birth, [DateTime? today]) {
  final now = today ?? DateTime.now();
  final current = DateTime(now.year, now.month, now.day);
  final selected = DateTime(birth.year, birth.month, birth.day);
  return !selected.isAfter(current);
}

/// Arabic error for the profile form, or null when everything looks fine.
String? registrationProfileError({
  required String name,
  required DateTime? birthDate,
  required String? gender,
  required String country,
  String address = '',
  String phone = '',
  DateTime? today,
}) {
  final trimmedName = name.trim();
  if (trimmedName.isEmpty) return 'أدخل الاسم';
  if (trimmedName.length > 100) return 'الاسم طويل جداً';

  if (birthDate == null) return 'اختر تاريخ الميلاد';
  if (!isValidBirthDate(birthDate, today)) return 'تاريخ الميلاد غير صالح';

  if (gender != null && gender != 'male' && gender != 'female') {
    return 'اختر الجنس';
  }

  final trimmedCountry = country.trim();
  if (trimmedCountry.isEmpty) return 'اختر الدولة';
  if (trimmedCountry.length > 80) return 'اسم الدولة طويل جداً';

  final place = splitAddress(address);
  if (place.city.isEmpty) return 'أدخل المدينة في حقل العنوان';
  if (place.city.length > maxCityLength) return 'اسم المدينة طويل جداً';
  if (place.street.length > maxStreetLength) return 'اسم الشارع طويل جداً';

  if (normalizePhoneNumber(phone) == null) return 'رقم الهاتف غير صالح';
  return null;
}
