// The figures the alert rules compare against: last-seen ratios and the
// ids of rows already looked at, saved in prefs between launches.

part of 'notification_service.dart';

/// Last-seen balances, goal ratios, and known IDs used to detect crossings.
class _NotificationSnapshot {
  final bool initialized;
  final double? remainingRatio;
  final double? spentRatio;
  final Map<String, double> goalRatios;
  final Set<String> knownTransactionIds;
  final Set<String> knownProcessedTokens;

  const _NotificationSnapshot({
    required this.initialized,
    required this.remainingRatio,
    required this.spentRatio,
    required this.goalRatios,
    required this.knownTransactionIds,
    required this.knownProcessedTokens,
  });

  bool sameAs(_NotificationSnapshot other) {
    if (identical(this, other)) return true;
    if (initialized != other.initialized) return false;
    if (remainingRatio != other.remainingRatio) return false;
    if (spentRatio != other.spentRatio) return false;
    if (goalRatios.length != other.goalRatios.length) return false;
    if (knownTransactionIds.length != other.knownTransactionIds.length) {
      return false;
    }
    if (knownProcessedTokens.length != other.knownProcessedTokens.length) {
      return false;
    }
    for (final entry in goalRatios.entries) {
      if (other.goalRatios[entry.key] != entry.value) return false;
    }
    return knownTransactionIds.containsAll(other.knownTransactionIds) &&
        knownProcessedTokens.containsAll(other.knownProcessedTokens);
  }

  factory _NotificationSnapshot.empty() {
    return const _NotificationSnapshot(
      initialized: false,
      remainingRatio: null,
      spentRatio: null,
      goalRatios: {},
      knownTransactionIds: {},
      knownProcessedTokens: {},
    );
  }

  /// Builds a snapshot from the live [TransactionStore].
  factory _NotificationSnapshot.fromStore(TransactionStore store) {
    final spent = store.maxBalance <= 0
        ? 0.0
        : store.cycleSpent / store.maxBalance;
    return _NotificationSnapshot(
      initialized: true,
      remainingRatio: store.remainingRatio,
      spentRatio: spent,
      goalRatios: {
        for (final goal in store.goals) goal.id: store.goalRatio(goal),
      },
      knownTransactionIds: {for (final item in store.transactions) item.id},
      knownProcessedTokens: Set<String>.of(store.processedPeriodTokens),
    );
  }

  String encode() => jsonEncode({
    'initialized': initialized,
    'remainingRatio': remainingRatio,
    'spentRatio': spentRatio,
    'goalRatios': goalRatios,
    'knownTransactionIds': knownTransactionIds.toList(),
    'knownProcessedTokens': knownProcessedTokens.toList(),
  });

  /// Restores a snapshot from prefs JSON; empty on missing or corrupt input.
  static _NotificationSnapshot decode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return _NotificationSnapshot.empty();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return _NotificationSnapshot.empty();

      final ratios = <String, double>{};
      final rawRatios = decoded['goalRatios'];
      if (rawRatios is Map) {
        rawRatios.forEach((key, value) {
          final amount = (value as num?)?.toDouble();
          if (amount == null) return;
          ratios[key.toString()] = amount;
        });
      }

      return _NotificationSnapshot(
        initialized: decoded['initialized'] == true,
        remainingRatio: (decoded['remainingRatio'] as num?)?.toDouble(),
        spentRatio: (decoded['spentRatio'] as num?)?.toDouble(),
        goalRatios: ratios,
        knownTransactionIds: {
          for (final item
              in decoded['knownTransactionIds'] as List? ?? const [])
            item.toString(),
        },
        knownProcessedTokens: {
          for (final item
              in decoded['knownProcessedTokens'] as List? ?? const [])
            item.toString(),
        },
      );
    } catch (_) {
      return _NotificationSnapshot.empty();
    }
  }
}
