// Live FX / gold quotes shown on the home exchange strip.
// Buy and sell stay null until a live source exists; the UI shows a minus.

/// One row: asset code, labels for the chip/pair, and buy/sell against SYP.
class ExchangeRate {
  /// Shown instead of a number when no quote is known.
  static const String unavailable = '−';

  /// Asset code ("USD", "XAU").
  final String code;

  /// Short chip text.
  final String chipLabel;

  /// Pair name shown in the card.
  final String pairLabel;

  /// Buy price in SYP, if known.
  final double? buy;

  /// Sell price in SYP, if known.
  final double? sell;

  /// When the quote was taken.
  final DateTime? updatedAt;

  /// A quote row.
  const ExchangeRate({
    required this.code,
    required this.chipLabel,
    required this.pairLabel,
    this.buy,
    this.sell,
    this.updatedAt,
  });
}
