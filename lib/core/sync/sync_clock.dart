// UTC clock helpers for last-write-wins sync comparisons and ISO timestamps.

/// Now in UTC, for sync metadata (updated_at, deleted_at).
DateTime syncNow() => DateTime.now().toUtc();

/// Device-local "now" for user-facing event times; never waits on the
/// network.
DateTime deviceNow() => DateTime.now();

/// An ISO timestamp from the server as UTC, or null when missing or bad.
DateTime? parseSyncDate(Object? raw) {
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString())?.toUtc();
}

/// [parseSyncDate], falling back to [syncNow].
DateTime parseSyncDateOrNow(Object? raw) => parseSyncDate(raw) ?? syncNow();

/// Event time in the device zone. Missing values stay missing so sync
/// cannot invent "now" when a record arrives later.
DateTime? parseEventLocal(Object? raw) => parseSyncDate(raw)?.toLocal();

/// Keeps the earlier instant so a later server receive time cannot replace
/// when the action was actually recorded on the device.
DateTime earlierDeviceEventTime(DateTime current, DateTime incoming) {
  if (incoming.toUtc().isAfter(current.toUtc())) {
    return current.toLocal();
  }
  return incoming.toLocal();
}

/// True when [incoming] should win over [current] (equal counts as newer).
bool newerOrEqual(DateTime? incoming, DateTime? current) {
  if (incoming == null) return current == null;
  if (current == null) return true;
  return !incoming.toUtc().isBefore(current.toUtc());
}

/// [value] (or now) as a UTC ISO string for the API.
String toSyncIso(DateTime? value) =>
    (value ?? syncNow()).toUtc().toIso8601String();
