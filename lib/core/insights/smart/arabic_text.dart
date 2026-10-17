// Small Arabic grammar helpers for generated text: counted nouns that agree
// with their number, category names with the definite article, and
// prepositions joined the way they are written.

/// One noun (with any adjective) in each form Arabic counting needs.
class ArabicCount {
  /// 1: the full phrase without the digit ("يوم واحد").
  final String one;

  /// 2: dual, accusative/genitive ("يومين").
  final String two;

  /// 3-10: plural ("أيام").
  final String few;

  /// 11-99: singular accusative ("يوماً").
  final String many;

  /// 100, 200...: singular genitive ("يوم").
  final String hundred;

  /// A noun given in all five forms.
  const ArabicCount({
    required this.one,
    required this.two,
    required this.few,
    required this.many,
    required this.hundred,
  });

  /// [n] with the noun in the form that agrees with it ("3 أيام").
  String of(int n) {
    if (n == 1) return one;
    if (n == 2) return two;
    final rest = n >= 100 ? n % 100 : n;
    if (n >= 100 && rest <= 2) return '$n $hundred';
    if (rest >= 3 && rest <= 10) return '$n $few';
    return '$n $many';
  }
}

/// The counted nouns and phrase helpers the generated texts share.
class Ar {
  Ar._();

  /// "يوم واحد", "3 أيام", "11 يوماً".
  static const days = ArabicCount(
    one: 'يوم واحد',
    two: 'يومين',
    few: 'أيام',
    many: 'يوماً',
    hundred: 'يوم',
  );

  /// Days in a row, for the usage streak.
  static const consecutiveDays = ArabicCount(
    one: 'يوم واحد',
    two: 'يومين متتاليين',
    few: 'أيام متتالية',
    many: 'يوماً متتالياً',
    hundred: 'يوم متتالٍ',
  );

  /// Expense counts.
  static const expenses = ArabicCount(
    one: 'مصروف واحد',
    two: 'مصروفين',
    few: 'مصاريف',
    many: 'مصروفاً',
    hundred: 'مصروف',
  );

  /// Small-expense counts (the "small amounts add up" insight).
  static const smallExpenses = ArabicCount(
    one: 'مصروف صغير واحد',
    two: 'مصروفين صغيرين',
    few: 'مصاريف صغيرة',
    many: 'مصروفاً صغيراً',
    hundred: 'مصروف صغير',
  );

  /// How many times something happened.
  static const times = ArabicCount(
    one: 'مرة واحدة',
    two: 'مرتين',
    few: 'مرات',
    many: 'مرة',
    hundred: 'مرة',
  );

  /// Goal counts.
  static const goals = ArabicCount(
    one: 'هدف واحد',
    two: 'هدفين',
    few: 'أهداف',
    many: 'هدفاً',
    hundred: 'هدف',
  );

  /// Active goal counts, in the nominative ("لديك هدفان نشطان").
  static const activeGoals = ArabicCount(
    one: 'هدف نشط واحد',
    two: 'هدفان نشطان',
    few: 'أهداف نشطة',
    many: 'هدفاً نشطاً',
    hundred: 'هدف نشط',
  );

  /// Shopping-list item counts.
  static const items = ArabicCount(
    one: 'عنصر واحد',
    two: 'عنصرين',
    few: 'عناصر',
    many: 'عنصراً',
    hundred: 'عنصر',
  );

  /// Payment counts. Dual in the nominative ("لديك دفعتان"), the case it
  /// is used in.
  static const payments = ArabicCount(
    one: 'دفعة واحدة',
    two: 'دفعتان',
    few: 'دفعات',
    many: 'دفعة',
    hundred: 'دفعة',
  );

  /// Month counts.
  static const months = ArabicCount(
    one: 'شهر واحد',
    two: 'شهرين',
    few: 'أشهر',
    many: 'شهراً',
    hundred: 'شهر',
  );

  static final RegExp _singleArabicWord = RegExp(r'^[ء-ي]+$');

  /// A category as a definite noun: "طعام" -> "الطعام". Names that cannot
  /// take the article (several words, Latin, «أخرى») become "تصنيف «…»".
  static String category(String name) {
    final trimmed = name.trim();
    if (trimmed == 'أخرى' || !_singleArabicWord.hasMatch(trimmed)) {
      return 'تصنيف «$trimmed»';
    }
    return trimmed.startsWith('ال') ? trimmed : 'ال$trimmed';
  }

  /// لِـ joined to a definite noun: "الطعام" -> "للطعام".
  static String li(String phrase) =>
      phrase.startsWith('ال') ? 'لل${phrase.substring(2)}' : 'ل$phrase';

  /// A user-given name in Arabic quotes: «name».
  static String quote(String name) => '«${name.trim()}»';

  /// Arabic weekday names by [DateTime.weekday].
  static const Map<int, String> weekdays = {
    DateTime.saturday: 'السبت',
    DateTime.sunday: 'الأحد',
    DateTime.monday: 'الاثنين',
    DateTime.tuesday: 'الثلاثاء',
    DateTime.wednesday: 'الأربعاء',
    DateTime.thursday: 'الخميس',
    DateTime.friday: 'الجمعة',
  };
}
