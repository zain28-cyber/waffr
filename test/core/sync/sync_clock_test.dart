// sync_clock helpers: parsing server timestamps, event times in the device
// zone, the earlier-event rule, last-write-wins comparison and ISO output.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/sync/sync_clock.dart';

void main() {
  test('syncNow is UTC and deviceNow is local', () {
    expect(syncNow().isUtc, isTrue);
    expect(deviceNow().isUtc, isFalse);
  });

  test('parseSyncDate reads ISO text as UTC', () {
    expect(
      parseSyncDate('2026-01-02T03:04:05Z'),
      DateTime.utc(2026, 1, 2, 3, 4, 5),
    );
    expect(parseSyncDate('2026-01-02T03:04:05Z')!.isUtc, isTrue);
    expect(parseSyncDate(null), isNull);
    expect(parseSyncDate('soon'), isNull);
    expect(parseSyncDate(42), isNull);
  });

  test('parseSyncDateOrNow falls back to now', () {
    final before = DateTime.now().toUtc();
    expect(parseSyncDateOrNow('bad').isBefore(before), isFalse);
    expect(parseSyncDateOrNow('2020-01-01T00:00:00Z'), DateTime.utc(2020));
  });

  test('parseEventLocal keeps missing values missing', () {
    expect(parseEventLocal(null), isNull);
    final local = parseEventLocal('2026-01-02T00:00:00Z')!;
    expect(local.isUtc, isFalse);
    expect(local.toUtc(), DateTime.utc(2026, 1, 2));
  });

  test('earlierDeviceEventTime keeps the earlier instant, as local time', () {
    final early = DateTime.utc(2026, 1, 1);
    final late = DateTime.utc(2026, 1, 2);
    expect(earlierDeviceEventTime(early, late), early.toLocal());
    expect(earlierDeviceEventTime(late, early), early.toLocal());
    expect(earlierDeviceEventTime(late, early).isUtc, isFalse);
  });

  test('newerOrEqual: equal wins, null rules', () {
    final a = DateTime.utc(2026, 1, 1);
    final b = DateTime.utc(2026, 1, 2);
    expect(newerOrEqual(b, a), isTrue);
    expect(newerOrEqual(a, a), isTrue);
    expect(newerOrEqual(a, b), isFalse);
    expect(newerOrEqual(a, null), isTrue);
    expect(newerOrEqual(null, a), isFalse);
    expect(newerOrEqual(null, null), isTrue);
    // Compared as instants, whatever the zone.
    expect(newerOrEqual(a.toLocal(), a), isTrue);
  });

  test('toSyncIso writes UTC ISO text, now when null', () {
    expect(toSyncIso(DateTime.utc(2026, 5, 6, 7)), '2026-05-06T07:00:00.000Z');
    expect(toSyncIso(null), endsWith('Z'));
  });
}
