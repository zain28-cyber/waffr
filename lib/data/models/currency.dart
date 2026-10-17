// Fixed currency catalog and helpers; SYP is always the app default.

/// The app's default currency; always enabled.
const String defaultCurrencyCode = 'SYP';

/// One entry in the catalog: ISO code, Arabic name, and display symbol.
class CurrencyInfo {
  /// ISO 4217 code ("USD").
  final String code;

  /// Arabic name ("دولار أمريكي").
  final String arabicName;

  /// Symbol shown after amounts ("\$").
  final String symbol;

  /// A catalog entry.
  const CurrencyInfo({
    required this.code,
    required this.arabicName,
    required this.symbol,
  });
}

/// Lookup + normalize against the built-in list (SYP plus common FX codes).
class Currencies {
  Currencies._();

  /// The Syrian pound.
  static const CurrencyInfo syp = CurrencyInfo(
    code: defaultCurrencyCode,
    arabicName: 'ليرة سورية',
    symbol: 'ل.س',
  );

  /// Every currency the app offers, SYP first.
  static const List<CurrencyInfo> catalog = [
    syp,
    CurrencyInfo(code: 'USD', arabicName: 'دولار أمريكي', symbol: '\$'),
    CurrencyInfo(code: 'EUR', arabicName: 'يورو', symbol: '€'),
    CurrencyInfo(code: 'TRY', arabicName: 'ليرة تركية', symbol: '₺'),
    CurrencyInfo(code: 'JOD', arabicName: 'دينار أردني', symbol: 'د.أ'),
    CurrencyInfo(code: 'AED', arabicName: 'درهم إماراتي', symbol: 'د.إ'),
    CurrencyInfo(code: 'SAR', arabicName: 'ريال سعودي', symbol: 'ر.س'),
    CurrencyInfo(code: 'GBP', arabicName: 'جنيه إسترليني', symbol: '£'),
    CurrencyInfo(code: 'EGP', arabicName: 'جنيه مصري', symbol: 'ج.م'),
    CurrencyInfo(code: 'KWD', arabicName: 'دينار كويتي', symbol: 'د.ك'),
    CurrencyInfo(code: 'QAR', arabicName: 'ريال قطري', symbol: 'ر.ق'),
    CurrencyInfo(code: 'CAD', arabicName: 'دولار كندي', symbol: 'C\$'),
    CurrencyInfo(code: 'AUD', arabicName: 'دولار أسترالي', symbol: 'A\$'),
    CurrencyInfo(code: 'CHF', arabicName: 'فرنك سويسري', symbol: 'CHF'),
    CurrencyInfo(code: 'SEK', arabicName: 'كرونة سويدية', symbol: 'kr'),
    CurrencyInfo(code: 'NOK', arabicName: 'كرونة نرويجية', symbol: 'kr'),
    CurrencyInfo(code: 'DKK', arabicName: 'كرونة دنماركية', symbol: 'kr'),
    CurrencyInfo(code: 'RUB', arabicName: 'روبل روسي', symbol: '₽'),
    CurrencyInfo(code: 'CNY', arabicName: 'يوان صيني', symbol: '¥'),
    CurrencyInfo(code: 'JPY', arabicName: 'ين ياباني', symbol: '¥'),
    CurrencyInfo(code: 'INR', arabicName: 'روبية هندية', symbol: '₹'),
  ];

  static final Map<String, CurrencyInfo> _byCode = {
    for (final item in catalog) item.code: item,
  };

  /// Known code → catalog row; unknown codes still get a placeholder CurrencyInfo.
  static CurrencyInfo of(String code) {
    return _byCode[normalize(code)] ??
        CurrencyInfo(
          code: normalize(code),
          arabicName: normalize(code),
          symbol: normalize(code),
        );
  }

  /// True when [code] is in the [catalog].
  static bool isKnown(String code) => _byCode.containsKey(normalize(code));

  /// Uppercases and falls back to SYP when blank.
  static String normalize(String? raw) {
    final code = (raw ?? '').trim().toUpperCase();
    return code.isEmpty ? defaultCurrencyCode : code;
  }

  /// The symbol of [code] (SYP when null).
  static String symbolOf(String? code) => of(normalize(code)).symbol;
}
