// Device notifications for real Waffr events. In-app history stays in
// NotificationService; this mirrors new alerts, the daily streak nudge and
// short comeback reminders.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:waffr/core/insights/smart/reminder_digest.dart';

/// Shows and schedules device (OS) notifications.
class SystemNotifications {
  SystemNotifications._();

  /// The app-wide service.
  static final SystemNotifications instance = SystemNotifications._();

  /// Android channel of every Waffr notification.
  static const String channelId = 'waffr_alerts';
  static const int _streakId = 41021;
  static const int _comebackSoonId = 41022;
  static const int _comebackLaterId = 41023;
  static const int _weeklyId = 41024;

  /// Payload of reminders that open the smart analysis when tapped.
  static const String smartPayload = 'smart';

  final StreamController<String> _taps = StreamController<String>.broadcast();

  /// Payloads of notifications tapped while the app is running.
  Stream<String> get taps => _taps.stream;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void>? _starting;
  bool _ready = false;
  bool _timeZoneReady = false;

  /// Sets up the plugin once; safe to call repeatedly.
  Future<void> initialize() {
    return _starting ??= _start();
  }

  /// Shows an alert now; [eventKey] gives it a stable id.
  Future<void> present({
    required String eventKey,
    required String title,
    required String body,
  }) async {
    await initialize();
    if (!_ready) return;
    try {
      await _plugin.show(
        id: _id(eventKey),
        title: title,
        body: body,
        notificationDetails: _details(),
      );
    } catch (_) {}
  }

  /// One reminder for tomorrow evening. Cancelled whenever the app is opened.
  Future<void> syncStreakReminder({
    required bool enabled,
    int streakCount = 0,
  }) async {
    await initialize();
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _streakId);
      if (!enabled || !_timeZoneReady) return;
      final text = ReminderDigest.streakText(streakCount);
      await _schedule(_streakId, (text.title, text.body), _tomorrowEvening());
    } catch (_) {}
  }

  /// Factual reminders for a user who stays away. Rescheduled on every
  /// open, so they only fire after days without the app: [soon] after two
  /// days, [later] after five, and [weekly] on Friday evening. Each is a
  /// title and body; null skips that slot.
  Future<void> syncComebackReminders({
    required bool enabled,
    (String, String)? soon,
    (String, String)? later,
    (String, String)? weekly,
  }) async {
    await initialize();
    if (!_ready) return;
    try {
      for (final id in const [_comebackSoonId, _comebackLaterId, _weeklyId]) {
        await _plugin.cancel(id: id);
      }
      if (!enabled || !_timeZoneReady) return;
      if (soon != null) {
        await _schedule(
          _comebackSoonId,
          soon,
          _localAt(daysFromNow: 2, hour: 20, minute: 30),
          payload: smartPayload,
        );
      }
      if (later != null) {
        await _schedule(
          _comebackLaterId,
          later,
          _localAt(daysFromNow: 5, hour: 20, minute: 30),
          payload: smartPayload,
        );
      }
      if (weekly != null) {
        await _schedule(
          _weeklyId,
          weekly,
          _nextFridayEvening(),
          payload: smartPayload,
        );
      }
    } catch (_) {}
  }

  /// When the first comeback reminder fires (two days later, 20:30), for
  /// writing its text ahead.
  static DateTime soonAt(DateTime now) =>
      DateTime(now.year, now.month, now.day + 2, 20, 30);

  /// When the second comeback reminder fires (five days later, 20:30).
  static DateTime laterAt(DateTime now) =>
      DateTime(now.year, now.month, now.day + 5, 20, 30);

  Future<void> _schedule(
    int id,
    (String, String) text,
    tz.TZDateTime when, {
    String? payload,
  }) {
    return _plugin.zonedSchedule(
      id: id,
      title: text.$1,
      body: text.$2,
      scheduledDate: when,
      notificationDetails: _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  /// Payload of the notification that launched the app, if one did.
  Future<String?> launchPayload() async {
    await initialize();
    if (!_ready) return null;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return null;
      return details?.notificationResponse?.payload;
    } catch (_) {
      return null;
    }
  }

  /// Removes every shown and scheduled notification.
  Future<void> cancelAll() async {
    await initialize();
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  Future<void> _start() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.UTC);
      _timeZoneReady = true;
    } catch (_) {
      _timeZoneReady = false;
    }

    try {
      final granted = await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_waffr'),
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) _taps.add(payload);
        },
      );
      _ready = granted != false;
      await _android?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          'تنبيهات وفّر',
          description: 'تنبيهات الرصيد والتوفير والأهداف',
          importance: Importance.defaultImportance,
        ),
      );
    } catch (error) {
      debugPrint('Notification setup failed: $error');
      _ready = false;
    }

    // Asked separately so a setup problem never skips the system prompt
    // (Android 13+; older versions allow notifications by default).
    await requestPermission();
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Whether the system lets the app post notifications. Null when unknown
  /// (not Android).
  Future<bool?> deviceNotificationsEnabled() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      return await _android?.areNotificationsEnabled();
    } catch (_) {
      return null;
    }
  }

  /// Shows the system permission prompt when Android still allows it.
  /// Returns true when notifications are allowed afterwards.
  Future<bool> requestPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final granted = await _android?.requestNotificationsPermission();
      return granted ?? (await deviceNotificationsEnabled() ?? false);
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
      return false;
    }
  }

  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        'تنبيهات وفّر',
        channelDescription: 'تنبيهات الرصيد والتوفير والأهداف',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: 'ic_stat_waffr',
      ),
    );
  }

  int _id(String eventKey) => eventKey.hashCode & 0x7fffffff;

  /// Local 19:30 tomorrow, stored as a UTC instant so no timezone database
  /// lookup is required.
  tz.TZDateTime _tomorrowEvening() =>
      _localAt(daysFromNow: 1, hour: 19, minute: 30);

  /// A local wall-clock time [daysFromNow] days ahead, as a UTC instant.
  tz.TZDateTime _localAt({
    required int daysFromNow,
    required int hour,
    required int minute,
  }) {
    final now = DateTime.now();
    final local = DateTime(
      now.year,
      now.month,
      now.day + daysFromNow,
      hour,
      minute,
    );
    return _utc(local);
  }

  tz.TZDateTime _nextFridayEvening() => _utc(nextFridayEvening(DateTime.now()));

  /// Friday 18:00 local after [now], at least half a day away.
  @visibleForTesting
  static DateTime nextFridayEvening(DateTime now) {
    var days = (DateTime.friday - now.weekday) % 7;
    var local = DateTime(now.year, now.month, now.day + days, 18);
    if (local.difference(now).inHours < 12) {
      days += 7;
      local = DateTime(now.year, now.month, now.day + days, 18);
    }
    return local;
  }

  tz.TZDateTime _utc(DateTime local) {
    final utc = local.toUtc();
    return tz.TZDateTime.utc(
      utc.year,
      utc.month,
      utc.day,
      utc.hour,
      utc.minute,
    );
  }
}
