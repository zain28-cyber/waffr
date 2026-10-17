// SyncDirty: the persisted "needs push" bit, the settings timestamp, the
// revision guard on clear, suppression during remote merges, listeners.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/sync/sync_dirty.dart';

import '../../helpers/store_harness.dart';

void main() {
  setUp(() async {
    await setUpStores();
  });

  test('mark sets the bit, clear resets it', () async {
    expect(await SyncDirty.isDirty(), isFalse);
    await SyncDirty.mark();
    expect(await SyncDirty.isDirty(), isTrue);
    expect(await SyncDirty.settingsUpdatedAt(), isNull);
    await SyncDirty.clear();
    expect(await SyncDirty.isDirty(), isFalse);
  });

  test('a settings mark stamps the settings time', () async {
    final before = DateTime.now().toUtc();
    await SyncDirty.mark(settings: true);
    final stamp = await SyncDirty.settingsUpdatedAt();
    expect(stamp!.isUtc, isTrue);
    expect(
      stamp.isBefore(before.subtract(const Duration(seconds: 1))),
      isFalse,
    );

    await SyncDirty.setSettingsUpdatedAt(DateTime.utc(2020, 1, 2));
    expect(await SyncDirty.settingsUpdatedAt(), DateTime.utc(2020, 1, 2));
  });

  test('an edit after the request was built keeps the bit set', () async {
    await SyncDirty.mark();
    final sent = SyncDirty.revision;
    await SyncDirty.mark();
    expect(SyncDirty.revision, sent + 1);

    await SyncDirty.clear(ifRevision: sent);
    expect(await SyncDirty.isDirty(), isTrue);
    await SyncDirty.clear(ifRevision: SyncDirty.revision);
    expect(await SyncDirty.isDirty(), isFalse);
  });

  test('suppressed marks are ignored entirely', () async {
    final revision = SyncDirty.revision;
    SyncDirty.suppressed = true;
    addTearDown(() => SyncDirty.suppressed = false);
    await SyncDirty.mark(settings: true);
    expect(SyncDirty.revision, revision);
    expect(await SyncDirty.isDirty(), isFalse);
    expect(await SyncDirty.settingsUpdatedAt(), isNull);
  });

  test('listeners run on every mark and can be removed', () async {
    var calls = 0;
    void listener() => calls++;
    SyncDirty.addListener(listener);
    SyncDirty.addListener(listener);
    await SyncDirty.mark();
    expect(calls, 1, reason: 'added once');
    SyncDirty.removeListener(listener);
    await SyncDirty.mark();
    expect(calls, 1);
  });
}
