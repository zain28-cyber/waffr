// Picks an expense category from the note the user types. It learns from
// the user's own history first ("شاورما" filed under طعام twice means
// طعام next time) and falls back to a dictionary of common words.

import 'package:waffr/data/models/transaction.dart';

/// Suggests a category for an expense note from history and a dictionary.
class CategorySuggester {
  // Normalized full note -> category -> count.
  final Map<String, Map<String, int>> _notes = {};
  // Normalized word -> category -> count.
  final Map<String, Map<String, int>> _words = {};

  /// Learns from the notes and categories of the expenses in [history].
  CategorySuggester(Iterable<WaffrTransaction> history) {
    for (final item in history) {
      final category = item.category;
      final note = item.note;
      if (!item.isExpense || category == null || note == null) continue;
      final normalized = normalize(note);
      if (normalized.isEmpty) continue;
      _bump(_notes, normalized, category);
      for (final word in _tokens(normalized)) {
        _bump(_words, word, category);
      }
    }
  }

  // Adds one sighting of [category] under [key].
  static void _bump(
    Map<String, Map<String, int>> map,
    String key,
    String category,
  ) {
    final counts = map.putIfAbsent(key, () => {});
    counts[category] = (counts[category] ?? 0) + 1;
  }

  /// The best category in [allowed] for [note], or null when unsure.
  String? suggest(String note, Iterable<String> allowed) {
    final options = allowed.toSet();
    final normalized = normalize(note);
    if (normalized.length < 2 || options.isEmpty) return null;

    // The same note filed before wins outright.
    final exact = _best(_notes[normalized], options);
    if (exact != null) return exact;

    // Words the user filed before count double per time they were seen.
    final scores = <String, double>{};
    final words = _tokens(normalized);
    for (final word in words) {
      _words[word]?.forEach((category, count) {
        if (options.contains(category)) {
          scores[category] = (scores[category] ?? 0) + 2.0 * count;
        }
      });
    }
    // Then the dictionary: short keywords must match a whole word, longer
    // ones may start a word or appear inside the note.
    for (final entry in _dictionary.entries) {
      if (!options.contains(entry.key)) continue;
      for (final keyword in entry.value) {
        final hit = keyword.length <= 2
            ? words.contains(keyword)
            : words.any((word) => word.startsWith(keyword)) ||
                  normalized.contains(keyword);
        if (hit) scores[entry.key] = (scores[entry.key] ?? 0) + 1.5;
      }
    }
    // One dictionary hit is enough; less than that is not a suggestion.
    if (scores.isEmpty) return null;
    final best = scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return best.value >= 1.5 ? best.key : null;
  }

  // The category in [options] seen most often in [counts].
  static String? _best(Map<String, int>? counts, Set<String> options) {
    if (counts == null) return null;
    String? best;
    var top = 0;
    counts.forEach((category, count) {
      if (options.contains(category) && count > top) {
        best = category;
        top = count;
      }
    });
    return best;
  }

  static final RegExp _diacritics = RegExp('[ً-ٰٟـ]');
  static final RegExp _separators = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

  /// Lower case, no tashkeel or tatweel, one form for alef/ya/ta marbuta.
  static String normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(_diacritics, '')
        .replaceAll(RegExp('[أإآ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(_separators, ' ')
        .trim();
  }

  // Words with common attached prefixes removed (و، ب، ل، ال، بال، لل).
  static List<String> _tokens(String normalized) {
    final words = <String>[];
    for (final raw in normalized.split(' ')) {
      if (raw.isEmpty) continue;
      var word = raw;
      for (final prefix in const ['وبال', 'بال', 'وال', 'فال', 'لل', 'ال']) {
        if (word.length > prefix.length + 1 && word.startsWith(prefix)) {
          word = word.substring(prefix.length);
          break;
        }
      }
      if (word.length > 3 && (word.startsWith('و') || word.startsWith('ب'))) {
        words.add(word.substring(1));
      }
      words.add(word);
    }
    return words;
  }

  // Keywords per built-in category, normalized once.
  static final Map<String, List<String>> _dictionary = {
    for (final entry in _rawDictionary.entries)
      entry.key: [for (final word in entry.value) normalize(word)],
  };

  static const Map<String, List<String>> _rawDictionary = {
    'طعام': [
      'مطعم',
      'غدا',
      'غداء',
      'عشا',
      'عشاء',
      'فطور',
      'ترويقة',
      'اكل',
      'أكل',
      'شاورما',
      'فلافل',
      'بيتزا',
      'برجر',
      'همبرغر',
      'قهوة',
      'كافيه',
      'شاي',
      'سندويش',
      'خبز',
      'فرن',
      'حلويات',
      'بوظة',
      'عصير',
      'خضار',
      'فواكه',
      'لحمة',
      'دجاج',
      'فروج',
      'بقالة',
      'سوبرماركت',
      'مشروب',
      'وجبة',
      'food',
      'restaurant',
      'coffee',
      'pizza',
      'burger',
      'kfc',
      'mcdonald',
    ],
    'مواصلات': [
      'تكسي',
      'تاكسي',
      'باص',
      'سرفيس',
      'ميكرو',
      'بنزين',
      'مازوت',
      'وقود',
      'اوبر',
      'كريم',
      'مواصلات',
      'اجرة',
      'أجرة',
      'قطار',
      'مترو',
      'موقف',
      'سيارة',
      'تصليح',
      'زيت',
      'كراج',
      'uber',
      'careem',
      'taxi',
      'fuel',
    ],
    'تسوق': [
      'ملابس',
      'تيشرت',
      'قميص',
      'بنطال',
      'حذاء',
      'صباط',
      'شنطة',
      'مول',
      'سوق',
      'تسوق',
      'امازون',
      'هدية',
      'عطر',
      'اكسسوار',
      'ساعة',
      'موبايل',
      'جوال',
      'سماعات',
      'amazon',
      'shein',
      'noon',
      'zara',
    ],
    'فواتير': [
      'فاتورة',
      'كهربا',
      'كهرباء',
      'مي',
      'ماء',
      'مياه',
      'انترنت',
      'نت',
      'رصيد',
      'خط',
      'اشتراك',
      'ايجار',
      'إيجار',
      'اجار',
      'غاز',
      'هاتف',
      'تلفون',
      'wifi',
      'netflix',
      'شاهد',
      'bill',
    ],
    'صحة': [
      'دوا',
      'دواء',
      'صيدلية',
      'دكتور',
      'طبيب',
      'مشفى',
      'مستشفى',
      'عيادة',
      'تحليل',
      'اسنان',
      'أسنان',
      'نظارات',
      'فيتامين',
      'pharmacy',
      'doctor',
    ],
    'ترفيه': [
      'سينما',
      'فيلم',
      'العاب',
      'ألعاب',
      'لعبة',
      'بلايستيشن',
      'نزهة',
      'رحلة',
      'حديقة',
      'مسرح',
      'حفلة',
      'نادي',
      'جيم',
      'ملاهي',
      'playstation',
      'game',
      'spotify',
      'cinema',
    ],
    'تعليم': [
      'كتاب',
      'كتب',
      'دورة',
      'كورس',
      'جامعة',
      'مدرسة',
      'قرطاسية',
      'دفتر',
      'قلم',
      'رسوم',
      'دروس',
      'معهد',
      'درس',
      'udemy',
      'course',
      'book',
    ],
  };
}
