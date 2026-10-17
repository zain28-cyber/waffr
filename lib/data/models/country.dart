// Country catalog for the profile form: Arabic name and international
// calling code. Arab countries come first, then the rest by Arabic name.

/// One country: ISO code, Arabic name and calling code.
class CountryInfo {
  /// ISO 3166 alpha-2 code ("SY").
  final String iso;

  /// Arabic name shown in the picker.
  final String arabicName;

  /// Calling code without the plus ("963").
  final String dialCode;

  /// A country entry.
  const CountryInfo({
    required this.iso,
    required this.arabicName,
    required this.dialCode,
  });

  /// "+963" style code shown beside the phone number.
  String get dialLabel => '+$dialCode';
}

/// The catalog and its search.
class Countries {
  Countries._();

  /// Arab countries, Syria first.
  static const List<CountryInfo> arab = [
    CountryInfo(iso: 'SY', arabicName: 'سوريا', dialCode: '963'),
    CountryInfo(iso: 'LB', arabicName: 'لبنان', dialCode: '961'),
    CountryInfo(iso: 'JO', arabicName: 'الأردن', dialCode: '962'),
    CountryInfo(iso: 'PS', arabicName: 'فلسطين', dialCode: '970'),
    CountryInfo(iso: 'IQ', arabicName: 'العراق', dialCode: '964'),
    CountryInfo(iso: 'SA', arabicName: 'السعودية', dialCode: '966'),
    CountryInfo(iso: 'AE', arabicName: 'الإمارات', dialCode: '971'),
    CountryInfo(iso: 'KW', arabicName: 'الكويت', dialCode: '965'),
    CountryInfo(iso: 'QA', arabicName: 'قطر', dialCode: '974'),
    CountryInfo(iso: 'BH', arabicName: 'البحرين', dialCode: '973'),
    CountryInfo(iso: 'OM', arabicName: 'عُمان', dialCode: '968'),
    CountryInfo(iso: 'YE', arabicName: 'اليمن', dialCode: '967'),
    CountryInfo(iso: 'EG', arabicName: 'مصر', dialCode: '20'),
    CountryInfo(iso: 'SD', arabicName: 'السودان', dialCode: '249'),
    CountryInfo(iso: 'LY', arabicName: 'ليبيا', dialCode: '218'),
    CountryInfo(iso: 'TN', arabicName: 'تونس', dialCode: '216'),
    CountryInfo(iso: 'DZ', arabicName: 'الجزائر', dialCode: '213'),
    CountryInfo(iso: 'MA', arabicName: 'المغرب', dialCode: '212'),
    CountryInfo(iso: 'MR', arabicName: 'موريتانيا', dialCode: '222'),
    CountryInfo(iso: 'SO', arabicName: 'الصومال', dialCode: '252'),
    CountryInfo(iso: 'DJ', arabicName: 'جيبوتي', dialCode: '253'),
    CountryInfo(iso: 'KM', arabicName: 'جزر القمر', dialCode: '269'),
  ];

  /// Every other country, by Arabic name.
  static const List<CountryInfo> others = [
    CountryInfo(iso: 'ET', arabicName: 'إثيوبيا', dialCode: '251'),
    CountryInfo(iso: 'AZ', arabicName: 'أذربيجان', dialCode: '994'),
    CountryInfo(iso: 'AR', arabicName: 'الأرجنتين', dialCode: '54'),
    CountryInfo(iso: 'AM', arabicName: 'أرمينيا', dialCode: '374'),
    CountryInfo(iso: 'ER', arabicName: 'إريتريا', dialCode: '291'),
    CountryInfo(iso: 'ES', arabicName: 'إسبانيا', dialCode: '34'),
    CountryInfo(iso: 'AU', arabicName: 'أستراليا', dialCode: '61'),
    CountryInfo(iso: 'EE', arabicName: 'إستونيا', dialCode: '372'),
    CountryInfo(iso: 'AF', arabicName: 'أفغانستان', dialCode: '93'),
    CountryInfo(iso: 'EC', arabicName: 'الإكوادور', dialCode: '593'),
    CountryInfo(iso: 'AL', arabicName: 'ألبانيا', dialCode: '355'),
    CountryInfo(iso: 'DE', arabicName: 'ألمانيا', dialCode: '49'),
    CountryInfo(iso: 'ID', arabicName: 'إندونيسيا', dialCode: '62'),
    CountryInfo(iso: 'AO', arabicName: 'أنغولا', dialCode: '244'),
    CountryInfo(iso: 'UY', arabicName: 'الأوروغواي', dialCode: '598'),
    CountryInfo(iso: 'UZ', arabicName: 'أوزبكستان', dialCode: '998'),
    CountryInfo(iso: 'UG', arabicName: 'أوغندا', dialCode: '256'),
    CountryInfo(iso: 'UA', arabicName: 'أوكرانيا', dialCode: '380'),
    CountryInfo(iso: 'IR', arabicName: 'إيران', dialCode: '98'),
    CountryInfo(iso: 'IE', arabicName: 'أيرلندا', dialCode: '353'),
    CountryInfo(iso: 'IS', arabicName: 'آيسلندا', dialCode: '354'),
    CountryInfo(iso: 'IT', arabicName: 'إيطاليا', dialCode: '39'),
    CountryInfo(iso: 'PY', arabicName: 'باراغواي', dialCode: '595'),
    CountryInfo(iso: 'PK', arabicName: 'باكستان', dialCode: '92'),
    CountryInfo(iso: 'BR', arabicName: 'البرازيل', dialCode: '55'),
    CountryInfo(iso: 'PT', arabicName: 'البرتغال', dialCode: '351'),
    CountryInfo(iso: 'BE', arabicName: 'بلجيكا', dialCode: '32'),
    CountryInfo(iso: 'BG', arabicName: 'بلغاريا', dialCode: '359'),
    CountryInfo(iso: 'BD', arabicName: 'بنغلاديش', dialCode: '880'),
    CountryInfo(iso: 'PA', arabicName: 'بنما', dialCode: '507'),
    CountryInfo(iso: 'BA', arabicName: 'البوسنة والهرسك', dialCode: '387'),
    CountryInfo(iso: 'BO', arabicName: 'بوليفيا', dialCode: '591'),
    CountryInfo(iso: 'PE', arabicName: 'بيرو', dialCode: '51'),
    CountryInfo(iso: 'BY', arabicName: 'بيلاروسيا', dialCode: '375'),
    CountryInfo(iso: 'TH', arabicName: 'تايلاند', dialCode: '66'),
    CountryInfo(iso: 'TW', arabicName: 'تايوان', dialCode: '886'),
    CountryInfo(iso: 'TM', arabicName: 'تركمانستان', dialCode: '993'),
    CountryInfo(iso: 'TR', arabicName: 'تركيا', dialCode: '90'),
    CountryInfo(iso: 'TD', arabicName: 'تشاد', dialCode: '235'),
    CountryInfo(iso: 'CZ', arabicName: 'التشيك', dialCode: '420'),
    CountryInfo(iso: 'CL', arabicName: 'تشيلي', dialCode: '56'),
    CountryInfo(iso: 'TZ', arabicName: 'تنزانيا', dialCode: '255'),
    CountryInfo(iso: 'JM', arabicName: 'جامايكا', dialCode: '1'),
    CountryInfo(iso: 'DO', arabicName: 'جمهورية الدومينيكان', dialCode: '1'),
    CountryInfo(iso: 'ZA', arabicName: 'جنوب أفريقيا', dialCode: '27'),
    CountryInfo(iso: 'SS', arabicName: 'جنوب السودان', dialCode: '211'),
    CountryInfo(iso: 'GE', arabicName: 'جورجيا', dialCode: '995'),
    CountryInfo(iso: 'DK', arabicName: 'الدنمارك', dialCode: '45'),
    CountryInfo(iso: 'RW', arabicName: 'رواندا', dialCode: '250'),
    CountryInfo(iso: 'RU', arabicName: 'روسيا', dialCode: '7'),
    CountryInfo(iso: 'RO', arabicName: 'رومانيا', dialCode: '40'),
    CountryInfo(iso: 'ZM', arabicName: 'زامبيا', dialCode: '260'),
    CountryInfo(iso: 'ZW', arabicName: 'زيمبابوي', dialCode: '263'),
    CountryInfo(iso: 'CI', arabicName: 'ساحل العاج', dialCode: '225'),
    CountryInfo(iso: 'LK', arabicName: 'سريلانكا', dialCode: '94'),
    CountryInfo(iso: 'SV', arabicName: 'السلفادور', dialCode: '503'),
    CountryInfo(iso: 'SK', arabicName: 'سلوفاكيا', dialCode: '421'),
    CountryInfo(iso: 'SI', arabicName: 'سلوفينيا', dialCode: '386'),
    CountryInfo(iso: 'SG', arabicName: 'سنغافورة', dialCode: '65'),
    CountryInfo(iso: 'SN', arabicName: 'السنغال', dialCode: '221'),
    CountryInfo(iso: 'SE', arabicName: 'السويد', dialCode: '46'),
    CountryInfo(iso: 'CH', arabicName: 'سويسرا', dialCode: '41'),
    CountryInfo(iso: 'RS', arabicName: 'صربيا', dialCode: '381'),
    CountryInfo(iso: 'CN', arabicName: 'الصين', dialCode: '86'),
    CountryInfo(iso: 'TJ', arabicName: 'طاجيكستان', dialCode: '992'),
    CountryInfo(iso: 'GA', arabicName: 'الغابون', dialCode: '241'),
    CountryInfo(iso: 'GH', arabicName: 'غانا', dialCode: '233'),
    CountryInfo(iso: 'GT', arabicName: 'غواتيمالا', dialCode: '502'),
    CountryInfo(iso: 'GN', arabicName: 'غينيا', dialCode: '224'),
    CountryInfo(iso: 'VE', arabicName: 'فنزويلا', dialCode: '58'),
    CountryInfo(iso: 'FI', arabicName: 'فنلندا', dialCode: '358'),
    CountryInfo(iso: 'FR', arabicName: 'فرنسا', dialCode: '33'),
    CountryInfo(iso: 'PH', arabicName: 'الفلبين', dialCode: '63'),
    CountryInfo(iso: 'VN', arabicName: 'فيتنام', dialCode: '84'),
    CountryInfo(iso: 'CY', arabicName: 'قبرص', dialCode: '357'),
    CountryInfo(iso: 'KG', arabicName: 'قيرغيزستان', dialCode: '996'),
    CountryInfo(iso: 'KZ', arabicName: 'كازاخستان', dialCode: '7'),
    CountryInfo(iso: 'CM', arabicName: 'الكاميرون', dialCode: '237'),
    CountryInfo(iso: 'HR', arabicName: 'كرواتيا', dialCode: '385'),
    CountryInfo(iso: 'CA', arabicName: 'كندا', dialCode: '1'),
    CountryInfo(iso: 'CU', arabicName: 'كوبا', dialCode: '53'),
    CountryInfo(iso: 'KR', arabicName: 'كوريا الجنوبية', dialCode: '82'),
    CountryInfo(iso: 'CR', arabicName: 'كوستاريكا', dialCode: '506'),
    CountryInfo(iso: 'CO', arabicName: 'كولومبيا', dialCode: '57'),
    CountryInfo(iso: 'CD', arabicName: 'الكونغو الديمقراطية', dialCode: '243'),
    CountryInfo(iso: 'KE', arabicName: 'كينيا', dialCode: '254'),
    CountryInfo(iso: 'LV', arabicName: 'لاتفيا', dialCode: '371'),
    CountryInfo(iso: 'LU', arabicName: 'لوكسمبورغ', dialCode: '352'),
    CountryInfo(iso: 'LT', arabicName: 'ليتوانيا', dialCode: '370'),
    CountryInfo(iso: 'MT', arabicName: 'مالطا', dialCode: '356'),
    CountryInfo(iso: 'ML', arabicName: 'مالي', dialCode: '223'),
    CountryInfo(iso: 'MY', arabicName: 'ماليزيا', dialCode: '60'),
    CountryInfo(iso: 'MG', arabicName: 'مدغشقر', dialCode: '261'),
    CountryInfo(iso: 'HU', arabicName: 'المجر', dialCode: '36'),
    CountryInfo(iso: 'MK', arabicName: 'مقدونيا الشمالية', dialCode: '389'),
    CountryInfo(iso: 'MX', arabicName: 'المكسيك', dialCode: '52'),
    CountryInfo(iso: 'GB', arabicName: 'المملكة المتحدة', dialCode: '44'),
    CountryInfo(iso: 'MN', arabicName: 'منغوليا', dialCode: '976'),
    CountryInfo(iso: 'MZ', arabicName: 'موزمبيق', dialCode: '258'),
    CountryInfo(iso: 'MD', arabicName: 'مولدوفا', dialCode: '373'),
    CountryInfo(iso: 'MC', arabicName: 'موناكو', dialCode: '377'),
    CountryInfo(iso: 'MM', arabicName: 'ميانمار', dialCode: '95'),
    CountryInfo(iso: 'NO', arabicName: 'النرويج', dialCode: '47'),
    CountryInfo(iso: 'AT', arabicName: 'النمسا', dialCode: '43'),
    CountryInfo(iso: 'NP', arabicName: 'نيبال', dialCode: '977'),
    CountryInfo(iso: 'NE', arabicName: 'النيجر', dialCode: '227'),
    CountryInfo(iso: 'NG', arabicName: 'نيجيريا', dialCode: '234'),
    CountryInfo(iso: 'NI', arabicName: 'نيكاراغوا', dialCode: '505'),
    CountryInfo(iso: 'NZ', arabicName: 'نيوزيلندا', dialCode: '64'),
    CountryInfo(iso: 'HT', arabicName: 'هايتي', dialCode: '509'),
    CountryInfo(iso: 'IN', arabicName: 'الهند', dialCode: '91'),
    CountryInfo(iso: 'HN', arabicName: 'هندوراس', dialCode: '504'),
    CountryInfo(iso: 'NL', arabicName: 'هولندا', dialCode: '31'),
    CountryInfo(iso: 'HK', arabicName: 'هونغ كونغ', dialCode: '852'),
    CountryInfo(iso: 'US', arabicName: 'الولايات المتحدة', dialCode: '1'),
    CountryInfo(iso: 'JP', arabicName: 'اليابان', dialCode: '81'),
    CountryInfo(iso: 'GR', arabicName: 'اليونان', dialCode: '30'),
  ];

  /// [arab] then [others].
  static const List<CountryInfo> all = [...arab, ...others];

  /// Name, ISO code or calling code. Arabic letter variants are folded so
  /// "الاردن" finds "الأردن".
  static List<CountryInfo> search(String query) {
    final needle = _fold(query);
    if (needle.isEmpty) return all;
    final digits = needle.replaceAll(RegExp(r'[^0-9]'), '');
    return [
      for (final item in all)
        if (_fold(item.arabicName).contains(needle) ||
            item.iso.toLowerCase() == needle ||
            (digits.isNotEmpty && item.dialCode.startsWith(digits)))
          item,
    ];
  }

  /// Lower case without the hamza and ta marbuta variants, for search.
  static String _fold(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp('[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll('ُ', '')
        .replaceAll('+', '');
  }
}
