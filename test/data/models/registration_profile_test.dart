// Sign-up profile: age, validation messages, phone normalization, address
// splitting, the auth body, and the country search used by the form.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/data/models/country.dart';
import 'package:waffr/data/models/registration_profile.dart';

void main() {
  final today = DateTime(2026, 9, 21);

  test('derives age from the selected birth date', () {
    expect(ageInYears(DateTime(2000, 9, 21), today), 26);
    expect(ageInYears(DateTime(2000, 9, 22), today), 25);
    expect(ageInYears(DateTime(2000, 1, 1), today), 26);
  });

  test('requires name, birth date and country', () {
    expect(
      registrationProfileError(
        name: '  ',
        birthDate: DateTime(2000, 1, 1),
        gender: 'male',
        country: 'سوريا',
        today: today,
      ),
      'أدخل الاسم',
    );
    expect(
      registrationProfileError(
        name: 'أحمد',
        birthDate: null,
        gender: 'male',
        country: 'سوريا',
        today: today,
      ),
      'اختر تاريخ الميلاد',
    );
    expect(
      registrationProfileError(
        name: 'أحمد',
        birthDate: DateTime(2027, 1, 1),
        gender: 'female',
        country: 'سوريا',
        today: today,
      ),
      'تاريخ الميلاد غير صالح',
    );
    expect(
      registrationProfileError(
        name: 'أحمد',
        birthDate: DateTime(2000, 1, 1),
        gender: 'male',
        country: '',
        today: today,
      ),
      'اختر الدولة',
    );
  });

  test('gender, phone and street are optional; the city is required', () {
    expect(
      registrationProfileError(
        name: 'أحمد',
        birthDate: DateTime(1998, 5, 12),
        gender: null,
        country: 'سوريا',
        address: 'اللاذقية',
        today: today,
      ),
      isNull,
    );
    expect(
      registrationProfileError(
        name: 'أحمد',
        birthDate: DateTime(1998, 5, 12),
        gender: null,
        country: 'سوريا',
        address: ' ، المشروع الثاني',
        today: today,
      ),
      'أدخل المدينة في حقل العنوان',
    );

    final profile = RegistrationProfile(
      name: 'أحمد',
      birthDate: DateTime.utc(1998, 5, 12),
      country: 'سوريا',
    );
    final body = profile.toAuthBody();
    expect(body.containsKey('gender'), isFalse);
    expect(body.containsKey('street'), isFalse);
    expect(body.containsKey('city'), isFalse);
    expect(body.containsKey('phone'), isFalse);
    expect(body['name'], 'أحمد');
    expect(body['country'], 'سوريا');
  });

  test('phone numbers drop the trunk zero and reject junk', () {
    expect(normalizePhoneNumber(''), '');
    expect(normalizePhoneNumber('0912 345 678'), '912345678');
    expect(normalizePhoneNumber('12'), isNull);
    expect(
      registrationProfileError(
        name: 'أحمد',
        birthDate: DateTime(1998, 5, 12),
        gender: 'female',
        country: 'سوريا',
        address: 'اللاذقية',
        phone: '12',
        today: today,
      ),
      'رقم الهاتف غير صالح',
    );

    final body = RegistrationProfile(
      name: 'أحمد',
      birthDate: DateTime.utc(1998, 5, 12),
      gender: 'female',
      country: 'سوريا',
      phone: '+963 912345678',
    ).toAuthBody();
    expect(body['phone'], '+963 912345678');
    expect(body['gender'], 'female');
  });

  test('one address field splits into city and street at the first comma', () {
    expect(splitAddress('اللاذقية، المشروع الثاني'), (
      city: 'اللاذقية',
      street: 'المشروع الثاني',
    ));
    expect(splitAddress('اللاذقية'), (city: 'اللاذقية', street: ''));
    expect(splitAddress('  '), (city: '', street: ''));
  });

  test('country search folds hamza and matches calling codes', () {
    expect(Countries.search('الاردن').map((item) => item.iso), contains('JO'));
    expect(Countries.search('+963').map((item) => item.iso), contains('SY'));
    expect(Countries.search('سوريا').first.dialLabel, '+963');
  });

  test('length limits and an invalid gender', () {
    String? error({
      String name = 'أحمد',
      String? gender,
      String country = 'سوريا',
      String address = 'حمص',
    }) => registrationProfileError(
      name: name,
      birthDate: DateTime(2000, 1, 1),
      gender: gender,
      country: country,
      address: address,
      today: today,
    );

    expect(error(name: 'ا' * 101), 'الاسم طويل جداً');
    expect(error(gender: 'other'), 'اختر الجنس');
    expect(error(country: 'ب' * 81), 'اسم الدولة طويل جداً');
    expect(error(address: 'م' * (maxCityLength + 1)), 'اسم المدينة طويل جداً');
    expect(
      error(address: 'حمص، ${'ش' * (maxStreetLength + 1)}'),
      'اسم الشارع طويل جداً',
    );
    expect(error(address: 'حمص, شارع'), isNull, reason: 'Latin comma too');
  });

  test('birth dates: today is valid, ages never go negative', () {
    expect(isValidBirthDate(DateTime(2026, 9, 21, 23), today), isTrue);
    expect(isValidBirthDate(DateTime(2026, 9, 22), today), isFalse);
    expect(ageInYears(DateTime(2030), today), 0);
  });

  test('phone numbers: separators are dropped and the length is checked', () {
    expect(normalizePhoneNumber('(09) 12-345-678'), '912345678');
    expect(normalizePhoneNumber('+963912345678'), isNull);
    expect(normalizePhoneNumber('1' * 15), isNull);
    expect(normalizePhoneNumber('123456'), '123456');
  });

  test('the auth body trims every field', () {
    final body = RegistrationProfile(
      name: ' أحمد ',
      birthDate: DateTime.utc(1998, 5, 12),
      country: ' سوريا ',
      city: ' حمص ',
      street: ' الحمراء ',
    ).toAuthBody();
    expect(body, {
      'name': 'أحمد',
      'birthdate': '1998-05-12T00:00:00.000Z',
      'country': 'سوريا',
      'city': 'حمص',
      'street': 'الحمراء',
    });
  });
}
