// Orchestrates cloud sync: push local changes to FastAPI /sync and merge
// the server's reply back into on-device stores without wiping offline data.
//
// Pieces: sync_request.dart builds the plain request from the stores,
// sync_codec.dart seals and encodes it (and decodes the reply) in a
// background isolate, sync_apply.dart merges the reply, and
// sync_sent_rows.dart remembers what the server already has.

import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:waffr/core/prefs/app_prefs.dart';
import 'package:waffr/core/security/data_key.dart';
import 'package:waffr/core/sync/api_config.dart';
import 'package:waffr/core/sync/auth_session.dart';
import 'package:waffr/core/sync/sync_apply.dart';
import 'package:waffr/core/sync/sync_clock.dart';
import 'package:waffr/core/sync/sync_codec.dart';
import 'package:waffr/core/sync/sync_dirty.dart';
import 'package:waffr/core/sync/sync_pull_policy.dart';
import 'package:waffr/core/sync/sync_request.dart';
import 'package:waffr/core/sync/sync_sent_rows.dart';
import 'package:waffr/core/sync/sync_tombstones.dart';
import 'package:waffr/data/services/usage_streak_service.dart';

/// How a sync attempt ended.
enum SyncStatus {
  /// Pushed and pulled (or nothing needed to go out).
  success,

  /// No network; changes stay saved on the device.
  offline,

  /// Guest, or the session ended; sign-in is needed.
  noAccount,

  /// The server refused or the reply could not be applied.
  failed,

  /// Another sync was already running; this one joins it.
  skipped,
}

/// Outcome of one sync attempt, including a user-facing Arabic message.
class SyncResult {
  /// How the attempt ended.
  final SyncStatus status;

  /// Arabic text for a snack bar.
  final String userMessage;

  /// A result with [status] and [userMessage].
  const SyncResult(this.status, this.userMessage);

  /// True when nothing went wrong (synced, or another sync is running).
  bool get ok => status == SyncStatus.success || status == SyncStatus.skipped;
}

/// Singleton that pushes dirty local data and pulls remote upserts and
/// deletes. Local storage stays the offline source of truth; a failed HTTP
/// call never overwrites or deletes local records.
///
/// What goes out: a sign-in, a forced sync, the first sync and the
/// one-time currency upgrade push every row. After a local edit the request
/// is built from every row, and rows whose fingerprint matches the last
/// successful push are dropped (see [SyncSentRows]). That check compares
/// row contents, not timestamps: rows are stamped with the phone's clock
/// (or the event date the user picked), while `lastSync` is the server's
/// time, so a timestamp filter would skip edits whenever the two clocks
/// disagree or a date is in the past.
class SyncService with WidgetsBindingObserver {
  SyncService._();

  /// The app-wide service.
  static final SyncService instance = SyncService._();

  static const Duration _debounce = Duration(seconds: 3);
  static const Duration _timeout = Duration(seconds: 25);
  static const Duration _minPullInterval = Duration(seconds: 20);
  static const String _currencySyncedKey = 'waffer_currency_synced';

  static const SyncResult _offlineResult = SyncResult(
    SyncStatus.offline,
    'لا يوجد اتصال. تم حفظ التغييرات محلياً',
  );
  static const SyncResult _failedResult = SyncResult(
    SyncStatus.failed,
    'تعذّر المزامنة. يمكنك المحاولة لاحقاً',
  );

  final SyncSentRows _sentRows = SyncSentRows();

  Timer? _debounceTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _syncing = false;
  bool _pending = false;
  bool _listenersAttached = false;
  bool _applying = false;
  bool _wasOnline = true;
  bool _resealPending = false;
  DateTime? _lastNetworkAttemptAt;

  /// True while a request is in flight (drives the settings spinner).
  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);

  /// Wires dirty, lifecycle and connectivity listeners, loads tombstones,
  /// then syncs once.
  Future<void> initialize() async {
    _attachListeners();
    await SyncTombstones.instance.ensureLoaded();
    await syncNow();
  }

  /// Debounces rapid local edits so they share one network round-trip.
  void scheduleSync() {
    if (_applying) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      unawaited(syncNow());
    });
  }

  /// Runs push and pull now. Needs a signed-in session; a clean pull right
  /// after another one is skipped. With [force] every row is pushed.
  Future<SyncResult> syncNow({bool force = false}) async {
    _debounceTimer?.cancel();

    if (_syncing) {
      _pending = true;
      return const SyncResult(SyncStatus.skipped, 'جارٍ المزامنة');
    }

    _syncing = true;
    isSyncing.value = true;

    try {
      return await _sync(force: force);
    } catch (_) {
      return _failedResult;
    } finally {
      _syncing = false;
      isSyncing.value = false;
      if (_resealPending) {
        _resealPending = false;
        _pending = false;
        unawaited(syncNow(force: true));
      } else if (_pending) {
        _pending = false;
        scheduleSync();
      }
    }
  }

  Future<SyncResult> _sync({required bool force}) async {
    if (!await AuthSession.instance.isLoggedIn()) {
      return const SyncResult(
        SyncStatus.noAccount,
        'في وضع الضيف تبقى بياناتك على جهازك فقط. سجّل الدخول للمزامنة',
      );
    }

    // A streak change that no successful sync carried yet (marked while
    // another sync was in flight, or before the app was closed) still has
    // to reach the server.
    final streak = UsageStreakService.instance;
    await streak.ensureLoaded();
    final dirtyRevision = SyncDirty.revision;
    final dirty = await SyncDirty.isDirty() || streak.hasUnsyncedChange;
    final lastSync = await AuthSession.instance.lastSyncAt();
    if (shouldSkipCleanPull(
      force: force,
      dirty: dirty,
      tombstoneCount: _tombstoneCount(),
      lastAttemptAt: _lastNetworkAttemptAt,
      now: DateTime.now(),
      minInterval: _minPullInterval,
    )) {
      return const SyncResult(SyncStatus.success, 'البيانات محدّثة');
    }

    final token = await AuthSession.instance.ensureToken();
    if (token == null) {
      return const SyncResult(
        SyncStatus.noAccount,
        'انتهت الجلسة. سجّل الدخول للمزامنة',
      );
    }

    // Sessions from before encryption have no data key. Signing in again
    // with the password creates or unlocks it.
    final cipher = await DataKeyStore.instance.cipher();
    if (cipher == null) {
      await AuthSession.instance.clearSession();
      return const SyncResult(
        SyncStatus.noAccount,
        'سجّل الدخول مجدداً لحماية بياناتك',
      );
    }

    // Build the plain request, then seal and encode it off the UI isolate.
    final prefs = await AppPrefs.instance;
    final currencySynced = prefs.getBool(_currencySyncedKey) ?? false;
    final fullPush = lastSync == null || force || !currencySynced;
    final streakRevision = streak.revision;
    final request = await buildSyncRequest(
      lastSync: lastSync,
      everyRow: fullPush || dirty,
    );
    final sentTombstones = tombstoneIdsIn(request);
    final encoded = await encodeSyncRequestInBackground(
      SyncRequestJob(
        payload: request,
        keyBytes: cipher.keyBytes,
        known: fullPush ? null : _sentRows.known,
      ),
    );

    final http.Response response;
    try {
      response = await _post(token, encoded.body);
    } on SocketException {
      return _offlineResult;
    } on TimeoutException {
      return const SyncResult(
        SyncStatus.offline,
        'انتهت مهلة الاتصال. تم حفظ التغييرات محلياً',
      );
    } on http.ClientException {
      return _offlineResult;
    }
    _lastNetworkAttemptAt = DateTime.now();

    if (response.statusCode == 401) {
      await AuthSession.instance.clearSession();
      _sentRows.clear();
      return const SyncResult(
        SyncStatus.failed,
        'انتهت الجلسة. سجّل الدخول مجدداً',
      );
    }
    if (response.statusCode != 200) return _failedResult;

    // Decode and open the reply off the UI isolate, then merge it.
    final DecodedSyncResponse decoded;
    try {
      decoded = await decodeSyncResponseInBackground(
        response.body,
        cipher.keyBytes,
      );
    } catch (_) {
      return _failedResult;
    }
    final body = decoded.body;
    if (body == null) return _failedResult;

    _applying = true;
    final bool applied;
    try {
      applied = await applySyncResponse(body, sentTombstones: sentTombstones);
    } finally {
      _applying = false;
    }
    if (!applied) {
      return const SyncResult(
        SyncStatus.failed,
        'تعذّر تحديث بياناتك من الحساب، فبقيت النسخة المحفوظة على جهازك',
      );
    }

    // Success: move the sync stamp, remember what the server now holds,
    // and clear the dirty bit unless something changed meanwhile.
    final serverTime = parseSyncDateOrNow(body['server_time']?.toString());
    await AuthSession.instance.saveLastSyncAt(serverTime);
    _sentRows.remember(
      encoded.sent,
      replace: fullPush,
      deleted: sentTombstones,
    );
    await SyncDirty.clear(ifRevision: dirtyRevision);
    if (!currencySynced) {
      await prefs.setBool(_currencySyncedKey, true);
    }
    // A streak recorded during this round trip goes out next time.
    if (await streak.markSynced(streakRevision)) {
      await SyncDirty.mark(settings: true);
    }
    // Rows saved before encryption came back readable; push everything
    // once more so the server copy is replaced with sealed text.
    _resealPending = decoded.sawPlaintext && !force;
    return const SyncResult(SyncStatus.success, 'تمت المزامنة');
  }

  // POST /sync with the encoded [body].
  Future<http.Response> _post(String token, String body) async {
    final base = await ApiConfig.baseUrl();
    return http
        .post(
          Uri.parse('$base/sync'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: body,
        )
        .timeout(ApiConfig.timeoutFor(base, local: _timeout));
  }

  int _tombstoneCount() {
    var total = 0;
    for (final collection in SyncCollection.values) {
      total += SyncTombstones.instance.of(collection).length;
    }
    return total;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(syncNow());
    }
  }

  // Subscribe to dirty marks, app resume, and reconnect-to-online events.
  void _attachListeners() {
    if (_listenersAttached) return;
    _listenersAttached = true;
    SyncDirty.addListener(scheduleSync);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_listenForConnectivity());
  }

  // When the device comes back online, flush whatever is still dirty.
  Future<void> _listenForConnectivity() async {
    final connectivity = Connectivity();
    try {
      _wasOnline = _isOnline(await connectivity.checkConnectivity());
    } catch (_) {
      _wasOnline = false;
    }

    _connectivitySub ??= connectivity.onConnectivityChanged.listen((results) {
      final online = _isOnline(results);
      final cameOnline = online && !_wasOnline;
      _wasOnline = online;
      if (cameOnline) {
        unawaited(syncNow());
      }
    });
  }

  static bool _isOnline(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }
}
