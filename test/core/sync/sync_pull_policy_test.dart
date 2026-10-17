// shouldSkipCleanPull: when a non-forced sync may skip the round trip.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/sync/sync_pull_policy.dart';

void main() {
  final now = DateTime.utc(2026, 9, 20, 17);
  const interval = Duration(seconds: 20);

  test('startup pull is not skipped when last_sync exists but no attempt this session', () {
    expect(
      shouldSkipCleanPull(
        force: false,
        dirty: false,
        tombstoneCount: 0,
        lastAttemptAt: null,
        now: now,
        minInterval: interval,
      ),
      isFalse,
    );
  });

  test('dirty or tombstones never skip', () {
    expect(
      shouldSkipCleanPull(
        force: false,
        dirty: true,
        tombstoneCount: 0,
        lastAttemptAt: now,
        now: now,
        minInterval: interval,
      ),
      isFalse,
    );
    expect(
      shouldSkipCleanPull(
        force: false,
        dirty: false,
        tombstoneCount: 1,
        lastAttemptAt: now,
        now: now,
        minInterval: interval,
      ),
      isFalse,
    );
  });

  test('recent clean pull is skipped; older pull is not', () {
    expect(
      shouldSkipCleanPull(
        force: false,
        dirty: false,
        tombstoneCount: 0,
        lastAttemptAt: now.subtract(const Duration(seconds: 5)),
        now: now,
        minInterval: interval,
      ),
      isTrue,
    );
    expect(
      shouldSkipCleanPull(
        force: false,
        dirty: false,
        tombstoneCount: 0,
        lastAttemptAt: now.subtract(const Duration(seconds: 21)),
        now: now,
        minInterval: interval,
      ),
      isFalse,
    );
  });

  test('force bypasses the cooldown', () {
    expect(
      shouldSkipCleanPull(
        force: true,
        dirty: false,
        tombstoneCount: 0,
        lastAttemptAt: now,
        now: now,
        minInterval: interval,
      ),
      isFalse,
    );
  });

  test('a pull exactly at the interval is not skipped', () {
    expect(
      shouldSkipCleanPull(
        force: false,
        dirty: false,
        tombstoneCount: 0,
        lastAttemptAt: now.subtract(interval),
        now: now,
        minInterval: interval,
      ),
      isFalse,
    );
  });
}
