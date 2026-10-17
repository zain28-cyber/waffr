// Decides when a non-forced sync may skip the HTTP round-trip.

/// True when a sync may skip the HTTP round-trip.
///
/// Dirty data and tombstones always sync. A clean pull is skipped only when
/// a recent attempt (within [minInterval]) already completed in this
/// process, so resume / reconnect / login do not stack duplicate requests.
bool shouldSkipCleanPull({
  required bool force,
  required bool dirty,
  required int tombstoneCount,
  required DateTime? lastAttemptAt,
  required DateTime now,
  required Duration minInterval,
}) {
  if (force || dirty || tombstoneCount > 0) return false;
  if (lastAttemptAt == null) return false;
  return now.difference(lastAttemptAt) < minInterval;
}
